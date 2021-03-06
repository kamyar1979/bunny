module http2;

import urllibparse;
import std.stdio;

import hunt.http.client;
import hunt.http.codec.http.frame;
import hunt.http.codec.http.model;
import hunt.http.codec.http.stream;

import hunt.collection;
import hunt.concurrency.FuturePromise;
import hunt.Exceptions;
import hunt.logging;
import hunt.util.Common;

import core.time;
import std.format;

void doRequest(string method, string url, byte[] payload)
{
	auto parsed = urlParse(url);

	HttpClientOptions clientOptions = new HttpClientOptions();
	clientOptions.setSecureConnectionEnabled(false);
	clientOptions.setFlowControlStrategy("simple");
	clientOptions.getTcpConfiguration().setIdleTimeout(60.seconds);
	clientOptions.setProtocol(HttpVersion.HTTP_2.toString());

	FuturePromise!(HttpClientConnection) promise = new FuturePromise!(HttpClientConnection)();
	HttpClient client = new HttpClient(clientOptions);

	client.connect(parsed.hostname, parsed.port.get(443), promise,
			new class ClientHttp2SessionListener
		{

		override Map!(int, int) onPreface(Session session)
		{
			infof("client preface: %s", session); Map!(int, int) settings = new HashMap!(int, int)();
				settings.put(SettingsFrame.HEADER_TABLE_SIZE,
					clientOptions.getMaxDynamicTableSize()); settings.put(SettingsFrame.INITIAL_WINDOW_SIZE,
					clientOptions.getInitialStreamSendWindow()); return settings;}

				override StreamListener onNewStream(Stream stream, HeadersFrame frame)
			{
				return null;}

				override void onSettings(Session session, SettingsFrame frame)
				{
					infof("client received settings frame: %s", frame.toString());
				}

				override void onPing(Session session, PingFrame frame)
				{
				}

				override void onReset(Session session, ResetFrame frame)
				{
					infof("client resets %s", frame.toString());}

					override void onClose(Session session, GoAwayFrame frame)
					{
						infof("client is closed %s", frame.toString());}

						override void onFailure(Session session, Exception failure)
						{
							errorf("client failure, %s", failure, session);}

							override bool onIdleTimeout(Session session)
							{
								return false;}
							}
);
							HttpFields fields = new HttpFields();
							fields.put(HttpHeader.ACCEPT, "application/json");
							fields.put(HttpHeader.USER_AGENT, "Hunt Client 1.0");
							fields.put(HttpHeader.CONTENT_LENGTH, "31");

							HttpRequest metaData = new HttpRequest(method, parsed.scheme, parsed.hostname,
								parsed.port.get(443), parsed.path, HttpVersion.HTTP_2, fields);

							const HttpConnection connection = promise.get();
							Http2ClientConnection clientConnection = cast(Http2ClientConnection) connection;

							FuturePromise!(Stream) streamPromise = new FuturePromise!(Stream)();
							auto http2Session = clientConnection.getHttp2Session();
							http2Session.newStream(new HeadersFrame(metaData, null,
								false), streamPromise, new class StreamListener
							{

								override void onHeaders(Stream stream, HeadersFrame frame)
								{
									infof("client received headers: %s", frame.toString());
								}

								override StreamListener onPush(Stream stream, PushPromiseFrame frame)
								{
									return null;}

									override void onData(Stream stream, DataFrame frame,
									hunt.util.Common.Callback callback)
									{
										infof("client received data: %s, %s",
										BufferUtils.toString(frame.getData()), frame.toString());
										callback.succeeded();}

										void onReset(Stream stream, ResetFrame frame,
										hunt.util.Common.Callback callback)
									{
											try
											{
												onReset(stream, frame); callback.succeeded();
											}
											catch (Exception x)
											{
												callback.failed(x);}
											}

											override void onReset(Stream stream, ResetFrame frame)
											{
												infof("client reset: %s, %s",
												stream, frame.toString());}

												override bool onIdleTimeout(Stream stream,
												Exception x)
												{
													errorf("the client stream %s is timeout",
													stream.toString()); return true;
												}

												override string toString()
												{
													return super.toString();}

												}
);
												Stream clientStream = streamPromise.get();
												infof("client stream id is %d",
												clientStream.getId());

												if (payload.length)
												{
													auto dataFrame = new DataFrame(clientStream.getId(),
													BufferUtils.toBuffer(payload), false);

													clientStream.data(dataFrame,
													new class NoopCallback
												{

														override void succeeded()
														{
															infof(
															"client sent small data successfully");
														}

														override void failed(Exception x)
														{
															infof("client sends small data failure");
														}
													}
);
												}
											}
