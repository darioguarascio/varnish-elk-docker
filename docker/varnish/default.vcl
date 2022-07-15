vcl 4.0;

import std;
import directors;

include "varnish_backends.vcl";


sub vcl_purge {
    return (synth(599, "Purged"));
}


# For WebSockets
sub vcl_pipe {
     if (req.http.upgrade) {
         set bereq.http.upgrade = req.http.upgrade;
     }
}

sub vcl_recv {

    if (req.method == "PURGE") {
        if (req.http.X-Purge-Key == std.getenv("VARNISH_PURGE_KEY")) {
            return (purge);
        }
        return(synth(405,"Not allowed."));
    }

    # normalize Accept-Encoding to reduce vary
    if (req.http.Accept-Encoding) {
        if (req.http.User-Agent ~ "MSIE 6") {
            unset req.http.Accept-Encoding;
        }
        elsif (req.http.Accept-Encoding ~ "gzip") {
            set req.http.Accept-Encoding = "gzip";
        }
        elsif (req.http.Accept-Encoding ~ "deflate") {
            set req.http.Accept-Encoding = "deflate";
        }
        else {
            unset req.http.Accept-Encoding;
        }
    }

    call host_to_backend_hinting;

    if (req.method != "GET") {
        return (pass);
    }

    if ( (std.getenv("ENV") == "dev" || std.getenv("ENV") == "staging" || std.getenv("ENV") == "testing" ) && req.url ~ "\?uncached") {
        return (pass);
    }

    return (hash);
}


sub vcl_hit {
    # set req.http.X-TTL = obj.ttl;
    # set req.http.X-Grace = obj.grace;

    if (obj.ttl >= 0s) {
        return (deliver);
    }

    if (obj.ttl + obj.grace > 0s) {
        set req.http.X-Graced = 1;
        return (deliver);
    }

    set req.hash_always_miss = true;
    return(restart);
}




sub vcl_backend_response {

    set beresp.http.X-Backend = beresp.backend.name;
    set beresp.do_gzip = true;
    set beresp.http.X-Retries = bereq.retries;

    if (std.getenv("VARNISH_PROJECT_CODE") != "") {
       set resp.http.X-Project = std.getenv("VARNISH_PROJECT_CODE");
    }

    # if (beresp.status >= 500 && bereq.retries < 2) {
    #     return(retry);
    # }

    if (beresp.status == 404) {
        set beresp.ttl   = 1s;
        set beresp.grace = 1h;
        return(deliver);
    }
    else if (beresp.status >= 400 && beresp.status != 410) {
        return(deliver);
    } else if (beresp.status == 410) {
        set beresp.grace = 240h;
        set beresp.ttl   = 3h;
        return(deliver);
    } else {

        # Using backend-generated headers to dynamically set TTL & grace period
        #
        if (std.integer(beresp.http.X-TTL, 0) >= 0) {
            set beresp.ttl = std.duration( beresp.http.X-TTL + "s", 0s);
        } else {
            set beresp.ttl = 0s;
        }

        if (std.integer(beresp.http.X-Grace, 0) >= 0) {
            set beresp.grace = std.duration(beresp.http.X-Grace + "s", 0s);
        } else {
            set beresp.grace = 0s;
        }
    }


    set beresp.http.X-Set-On = now;
    set beresp.http.X-TTL    = regsub(beresp.ttl, "\.000$", "");
    set beresp.http.X-Grace  = regsub(beresp.grace, "\.000$", "");

    return (deliver);

}




sub vcl_deliver {
    set resp.http.X-Env = std.getenv("ENV");

    if (std.getenv("VARNISH_PROJECT_CODE") != "") {
       set resp.http.X-Project = std.getenv("VARNISH_PROJECT_CODE");
    }

    if (!req.http.X-VR && resp.http.X-Env != "dev") {
        unset resp.http.X-Powered-By;
        unset resp.http.Server;
        unset resp.http.TTL;
        unset resp.http.X-Varnish;
        unset resp.http.X-Backend;
        unset resp.http.X-Db;
        unset resp.http.X-Me;
        unset resp.http.Via;
        unset resp.http.X-Project;
        unset resp.http.X-ProjectVersion;
        unset resp.http.X-Env;
        unset resp.http.X-Grace;
        unset resp.http.X-TTL;
        unset resp.http.X-VarnishCache;
        unset resp.http.X-FullCache-Status;
        unset resp.http.X-FullCache-Set;
        unset resp.http.X-Set-On;
        unset resp.http.X-Retries;
        unset resp.http.X-Rid;
        unset resp.http.X-Rsl;
        unset resp.http.Age;
        unset resp.http.X-Metrics;
        unset resp.http.X-ABTestHash;
        unset resp.http.PH-ABTestHash;
        unset resp.http.X-Timing;
    } else {
        set resp.http.X-Cache = obj.hits;
        set resp.http.X-Reset = req.restarts;
        set resp.http.X-lb = server.hostname;
    }
}



sub vcl_backend_error {
    set beresp.do_gzip = true;
    set beresp.http.X-Retries = bereq.retries;
    set beresp.http.X-Backend = beresp.backend.name;

    if (std.getenv("VARNISH_PROJECT_CODE") != "") {
       set beresp.http.X-Project = std.getenv("VARNISH_PROJECT_CODE");
    }

    set beresp.http.Content-Type = "text/html; charset=utf-8";
    set beresp.http.Retry-After = "5";
    synthetic( {"<!doctype html>
<html lang='en'>
<head>
    <meta charset='utf-8'>
    <meta http-equiv='X-UA-Compatible' content='IE=edge'>
    <meta name='viewport' content='width=device-width, initial-scale=1'>

    <title>"} + beresp.status + " " + beresp.reason + {"</title>

    <link rel='stylesheet' href='https://unpkg.com/tailwindcss@1.0.4/dist/tailwind.min.css'>
    <style>
        * { 'Whitney SSm A', 'Whitney SSm B', 'Helvetica Neue', Helvetica, Arial, Sans-Serif; }
        .error-text { font-size: 130px; }
        @media (min-width: 768px) {
          .error-text { font-size: 220px; }
        }
    </style>

</head>
<body class='bg-gray-200'>
    <div class='bg-gray-800 text-white py-3 px-4 text-center fixed left-0 bottom-0 right-0 z-40'>
        "} + beresp.reason + {"
        <span class='font-mono'>XID: "} + bereq.xid + {"</span>
    </div>
<div class='h-screen w-screen bg-blue-600 flex justify-center content-center flex-wrap'>
  <p class='font-sans text-white error-text'>"} + beresp.status + {"</p>
</div>

</body>
</html>
"} );
    return (deliver);
}



sub vcl_synth {
    unset resp.http.X-Powered-By;
    unset resp.http.Via;
    unset resp.http.Server;

    if (resp.status == 401) {
        set resp.http.Content-Type = "text/plain; charset=utf-8";
        set resp.http.WWW-Authenticate = "Basic realm=Secured";
        synthetic({" unauth "});
    }

    return(deliver);
}
