return [[
let args = listNew();
let result = libCall("/www/website.tux/site.mxl", "WebsiteTuxSite.Register", args);
exit(toNumber(result));
]]
