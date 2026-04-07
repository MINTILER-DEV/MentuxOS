return [[
namespace Sites.WebsiteTux;

using Mentux.Web.MtxDT;
using System.String;

class WebsiteTuxSite {
    static object Home() {
        let page = Webpage.New();
        Webpage.SetTitle(page, "website.tux");
        Webpage.AddHeading(page, "Welcome to website.tux");
        Webpage.AddText(page, "This site is hosted by MtxDT, the Mentux-native virtual web platform.");
        Webpage.AddText(page, "Routes can be static or dynamic, and data can persist through Roblox DataStoreService.");
        Webpage.AddLink(page, "About", "/about");
        Webpage.AddLink(page, "Visitor Counter", "/counter");
        Webpage.AddLink(page, "Live Lobby", "/live");
        return Response.Ok(page);
    }

    static object About() {
        let page = Webpage.New();
        Webpage.SetTitle(page, "About website.tux");
        Webpage.AddHeading(page, "About");
        Webpage.AddText(page, "Hostname resolution, virtual IPs, and route serving are all handled inside Mentux.");
        Webpage.AddText(page, "This is a believable virtual network, not the real internet.");
        Webpage.AddLink(page, "Back Home", "/");
        return Response.Ok(page);
    }

    static object Counter(object request) {
        let visits = Store.GetNumber("website.tux", "counter");
        visits = visits + 1;
        Store.Set("website.tux", "counter", visits);

        let page = Webpage.New();
        Webpage.SetTitle(page, "Visitor Counter");
        Webpage.AddHeading(page, "Visitor Counter");
        Webpage.AddText(page, String.concat("This route has been opened ", visits));
        Webpage.AddText(page, " time(s) through the shared MtxDT storage layer.");
        Webpage.AddLink(page, "Back Home", "/");
        return Response.Ok(page);
    }

    static object Live(object request) {
        let page = Webpage.New();
        Webpage.SetTitle(page, "Live Lobby");
        Webpage.AddHeading(page, "Live Lobby");
        Webpage.AddText(page, "This page subscribes to a shared MtxDT live channel.");
        Webpage.AddText(page, "Use the browser panel below to publish and poll lobby messages.");
        Webpage.AddLink(page, "Back Home", "/");
        Webpage.SetChannel(page, "website.tux:lobby");
        return Response.Ok(page);
    }

    static int Register() {
        let site = Server.Listen("website.tux", "10.0.0.5", 80, "/www/website.tux");
        Server.RouteStatic(site, "/", WebsiteTuxSite.Home());
        Server.RouteStatic(site, "/about", WebsiteTuxSite.About());
        Server.RouteDynamic(site, "/counter", "/www/website.tux/site.mxl", "WebsiteTuxSite.Counter");
        Server.RouteDynamic(site, "/live", "/www/website.tux/site.mxl", "WebsiteTuxSite.Live");
        Server.Register(site);
        return 0;
    }
}
]]
