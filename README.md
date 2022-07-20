# varnish elk docker

This is a simple docker configuration to have a varnish instance running using a mounted backend config file.
The goal of this configuration is to provide a json-formatted log output to be redirected to remote a syslogger.


## Sample varnish config

```
backend node_0 {
    .host = "webserer";
    .port = "3000";
    .connect_timeout = 3s;
    .first_byte_timeout = 10s;
    .between_bytes_timeout = 1s;
}

sub vcl_init {
    new be_web = directors.round_robin();
    be_web.add_backend(node);
}

sub host_to_backend_hinting {
    set req.backend_hint = be_web.backend();
}

sub vcl_deliver {
    set resp.http.X-Project = req.http.X-Project;
}
