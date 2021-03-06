import std.stdio;
import std.getopt;
import std.json;
import std.array;
import std.conv;
import std.format;
import std.uri;
import std.string;
import std.regex;
import colorize;
import std.algorithm.iteration;
import hunt.http;
import hunt.util.MimeType;
import http2;

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

enum Method : string
{
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
    if (indexOf(item, ':') != -1)
    {
      auto val = split(item, ':');
      result.headers[val[0]] = strip(val[1], "\"");
    }
    else if (indexOf(item, '=') != -1)
    {
      auto val = split(item, '=');
      result.params[val[0]] = strip(val[1], "\"");
    }
  }
  return result;
}

void main(string[] args)
{
  auto p = parseArgs(args);
  HttpClientRequest request;

  auto rb = new RequestBuilder();
  foreach (key, value; p.headers)
  {
    rb.header(key, value);
  }
  switch (p.method)
  {
  case Method.get:
  case Method.del:
  case Method.options:
    request = rb.url(p.url)
      .method(p.method, null).build();
    // doRequest(p.method, p.url, null);
    break;
  case Method.post:
  case Method.put:
  case Method.patch:
    const json = JSONValue(p.params);
    auto b = HttpBody.create(MimeType.APPLICATION_JSON_UTF_8.toString(), toJSON(json));
    request = rb.url(p.url).method(p.method, b).build();
    break;
  default:
    request = rb.url(p.url).build();
    break;
  }
  auto client = new HttpClient();
  scope (exit)
  {
    client.close();
  }

  auto response = client.newCall(request).execute();
  cwritefln("%s %s", response.getHttpVersion(), to!string(response.getStatus()).color(fg.blue));
  foreach (key, value; response.headers)
  {
    cwritefln("%s: %s", key.color(fg.light_cyan), value.color(fg.white));
  }
  writeln();
  if (startsWith(response.headers(HttpHeader.CONTENT_TYPE)[0], MimeType.APPLICATION_JSON.toString))
  {
    auto obj = parseJSON(response.getBody().asString());
    prettyPrint(obj);
    writeln();
  }
  else
  {
    writeln(response.getBody().asString());
  }

}
