return {
	["Webpage.New"] = [[
let page = objNew("MtxDT.Page", "");
objSet(page, "title", "Untitled");
objSet(page, "blocks", listNew());
objSet(page, "channel", "");
libReturn(page);
]],
	["Webpage.SetTitle"] = [[
if argc() >= 2 {
	objSet(argv(1), "title", argv(2));
}
libReturn(argv(1));
]],
	["Webpage.SetChannel"] = [[
if argc() >= 2 {
	objSet(argv(1), "channel", argv(2));
}
libReturn(argv(1));
]],
	["Webpage.AddHeading"] = [[
let block = objNew("MtxDT.Block", "");
objSet(block, "kind", "heading");
objSet(block, "text", argv(2));
push(objGet(argv(1), "blocks"), block);
libReturn(argv(1));
]],
	["Webpage.AddText"] = [[
let block = objNew("MtxDT.Block", "");
objSet(block, "kind", "text");
objSet(block, "text", argv(2));
push(objGet(argv(1), "blocks"), block);
libReturn(argv(1));
]],
	["Webpage.AddLink"] = [[
let block = objNew("MtxDT.Block", "");
objSet(block, "kind", "link");
objSet(block, "text", argv(2));
objSet(block, "href", argv(3));
push(objGet(argv(1), "blocks"), block);
libReturn(argv(1));
]],
	["Response.Ok"] = [[
let response = objNew("MtxDT.Response", "");
objSet(response, "status", 200);
objSet(response, "page", argv(1));
libReturn(response);
]],
	["Response.NotFound"] = [[
let page = objNew("MtxDT.Page", "");
objSet(page, "title", "Not Found");
objSet(page, "blocks", listNew());
let block = objNew("MtxDT.Block", "");
objSet(block, "kind", "text");
objSet(block, "text", argv(1));
push(objGet(page, "blocks"), block);
let response = objNew("MtxDT.Response", "");
objSet(response, "status", 404);
objSet(response, "page", page);
libReturn(response);
]],
	["Server.Listen"] = [[
let site = objNew("MtxDT.Site", "");
objSet(site, "host", argv(1));
objSet(site, "ip", argv(2));
objSet(site, "port", argv(3));
objSet(site, "rootPath", argv(4));
objSet(site, "routes", listNew());
libReturn(site);
]],
	["Server.RouteStatic"] = [[
let route = objNew("MtxDT.Route", "");
objSet(route, "path", argv(2));
objSet(route, "kind", "static");
objSet(route, "response", argv(3));
push(objGet(argv(1), "routes"), route);
libReturn(argv(1));
]],
	["Server.RouteDynamic"] = [[
let route = objNew("MtxDT.Route", "");
objSet(route, "path", argv(2));
objSet(route, "kind", "dynamic");
objSet(route, "handlerPath", argv(3));
objSet(route, "handlerExport", argv(4));
push(objGet(argv(1), "routes"), route);
libReturn(argv(1));
]],
	["Server.Register"] = [[
let args = listNew();
push(args, argv(1));
libReturn(sysInvoke("mtxdt.registerSite", args));
]],
	["Dns.Resolve"] = [[
let args = listNew();
if argc() >= 1 {
	push(args, argv(1));
}
if argc() >= 2 {
	push(args, argv(2));
}
libReturn(sysInvoke("mtxdt.resolve", args));
]],
	["Client.Get"] = [[
let args = listNew();
push(args, argv(1));
push(args, "GET");
push(args, listNew());
push(args, "");
libReturn(sysInvoke("mtxdt.request", args));
]],
	["Socket.Subscribe"] = [[
let args = listNew();
push(args, argv(1));
libReturn(sysInvoke("mtxdt.socket.subscribe", args));
]],
	["Socket.Publish"] = [[
let args = listNew();
push(args, argv(1));
push(args, argv(2));
libReturn(sysInvoke("mtxdt.socket.publish", args));
]],
	["Socket.Poll"] = [[
libReturn(sysInvoke("mtxdt.socket.poll", listNew()));
]],
	["Store.Get"] = [[
let args = listNew();
push(args, argv(1));
push(args, argv(2));
libReturn(sysInvoke("mtxdt.store.get", args));
]],
	["Store.Set"] = [[
let args = listNew();
push(args, argv(1));
push(args, argv(2));
push(args, argv(3));
libReturn(sysInvoke("mtxdt.store.set", args));
]],
	["Store.GetNumber"] = [[
let args = listNew();
push(args, argv(1));
push(args, argv(2));
let value = sysInvoke("mtxdt.store.get", args);
if value == false {
	libReturn(0);
}
libReturn(toNumber(value));
]],
}
