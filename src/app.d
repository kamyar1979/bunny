import std.stdio;
import std.getopt;
import std.json;
import std.array;
import std.conv;
import std.format;
import std.uri;
import requests;
import std.string;
import std.regex;
import colorize;
import std.algorithm.searching;
import std.net.curl : HTTP;
import std.typecons : tuple, Tuple;

void prettyPrintValue(JSONValue value, ushort tabs = 0)
{
    write(" ".replicate(4 * tabs));
    switch (value.type())
    {
    case JSONType.STRING:
        cwritef("\"%s\"", value.str().color(fg.yellow));
        break;
    case JSONType.INTEGER:
    case JSONType.FLOAT:
    case JSONType.TRUE:
    case JSONType.FALSE:
        cwrite(to!string(value).color(fg.blue));
        break;
    case JSONType.ARRAY:
        auto isFirstElement = true;
        writeln("[");
        foreach (elem; value.array())
        {
            if (!isFirstElement)
                writeln(",");
            isFirstElement = false;
            prettyPrintValue(elem, to!ushort(tabs + 2u));
        }
        writeln();
        write(" ".replicate(4 * (tabs + 1)));
        write("]");
        break;
    default:
        prettyPrint(value, to!ushort(tabs + 1u));
        break;
    }

}

void prettyPrint(JSONValue obj, ushort tabs = 0)
{
    write(" ".replicate(4 * tabs));
    cwriteln("{".color(fg.white));
    auto isFirst = true;
    foreach (item; obj.object().byKeyValue())
    {
        if (!isFirst)
            writeln(",");
        isFirst = false;
        write(" ".replicate(4 * (tabs + 1)));
        cwrite(format("\"%s\"", item.key).color(fg.light_blue));
        write(" : ");
        prettyPrintValue(item.value, tabs);
    }
    writeln();
    write(" ".replicate(4 * tabs));
    write("}");
}

struct ParsedArgs
{
    string url;
    string method;
    string[string] headers;
    string[string] params;
}

enum Method : string {
	get = "GET",
	post = "POST",
	put = "PUT",
	patch = "PATCH",
	del = "DELETE",
	options = "OPTIONS"
}

ParsedArgs parseArgs(string[] args)
{
    assert(args.length >= 2);
    string[] data;
    ParsedArgs result;
    switch (toUpper(args[1]))
    {
    case Method.get:
    case Method.post:
    case Method.put:
    case Method.patch:
    case Method.del:
    case Method.options:
    
        assert(args.length >= 3);
        result.method = toUpper(args[1]);
        result.url = args[2];
        if (args.length > 3)
            data = args[3 .. $];
        break;

    default:
        result.method = Method.get;
        result.url = args[1];
        if (args.length > 2)
            data = args[2 .. $];

    }
    foreach (string item; data)
    {
    	if(indexOf(item, ':') != -1) {
    		auto val = split(item, ':');
    		result.headers[val[0]] = val[1];
    	} else if (indexOf(item, '=') != -1) {
    		auto val = split(item, '=');
    		result.params[val[0]] = val[1];    		
    	}
    }
    return result;
}

void main(string[] args)
{
	auto  p = parseArgs(args);
    scope (exit)
    {
        auto req = Request();
        req.sslSetVerifyPeer(false);
        foreach(key, value; p.headers) {
        	req.headers[key] = value;
        }
        Response res;
        switch (p.method)
        {
        case Method.get:
            res = req.get(p.url);
            break;
        case Method.post:
	        auto json = JSONValue(p.params);
            res = req.post(p.url, toJSON(json) , "application/json");
            break;
        default:
            res = req.get(p.url);
            break;

        }
        cwritefln("HTTP/1.1 %s", to!string(res.code).color(fg.blue));
        foreach (key, value; res.responseHeaders)
        {
            cwritefln("%s: %s", key.color(fg.light_cyan), value.color(fg.white));
        }
        writeln();
        if ("content-type" in res.responseHeaders
                && startsWith(res.responseHeaders["content-type"], "application/json"))
        {
            auto obj = parseJSON(to!string(res.responseBody));
            prettyPrint(obj);
            writeln();
        }
    }
}
