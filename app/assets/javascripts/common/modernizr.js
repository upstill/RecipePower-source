/**
 * Created by upstill on 3/9/17.
 */
/*! modernizr 3.3.1 (Custom Build) | MIT *
 * https://modernizr.com/download/?-placeholder-setclasses !*/
!function (e, n, a) {
    function s(e, n) {
        return typeof e === n
    }

    function o() {
        var e, n, a, o, t, i, c;
        for (var f in r)if (r.hasOwnProperty(f)) {
            if (e = [], n = r[f], n.name && (e.push(n.name.toLowerCase()), n.options && n.options.aliases && n.options.aliases.length))for (a = 0; a < n.options.aliases.length; a++)e.push(n.options.aliases[a].toLowerCase());
            for (o = s(n.fn, "function") ? n.fn() : n.fn, t = 0; t < e.length; t++)i = e[t], c = i.split("."), 1 === c.length ? Modernizr[c[0]] = o : (!Modernizr[c[0]] || Modernizr[c[0]]instanceof Boolean || (Modernizr[c[0]] = new Boolean(Modernizr[c[0]])), Modernizr[c[0]][c[1]] = o), l.push((o ? "" : "no-") + c.join("-"))
        }
    }

    function t(e) {
        var n = f.className, a = Modernizr._config.classPrefix || "";
        if (u && (n = n.baseVal), Modernizr._config.enableJSClass) {
            var s = new RegExp("(^|\\s)" + a + "no-js(\\s|$)");
            n = n.replace(s, "$1" + a + "js$2")
        }
        Modernizr._config.enableClasses && (n += " " + a + e.join(" " + a), u ? f.className.baseVal = n : f.className = n)
    }

    function i() {
        return "function" != typeof n.createElement ? n.createElement(arguments[0]) : u ? n.createElementNS.call(n, "http://www.w3.org/2000/svg", arguments[0]) : n.createElement.apply(n, arguments)
    }

    var l = [], r = [], c = {
        _version: "3.3.1",
        _config: {classPrefix: "", enableClasses: !0, enableJSClass: !0, usePrefixes: !0},
        _q: [],
        on: function (e, n) {
            var a = this;
            setTimeout(function () {
                n(a[e])
            }, 0)
        },
        addTest: function (e, n, a) {
            r.push({name: e, fn: n, options: a})
        },
        addAsyncTest: function (e) {
            r.push({name: null, fn: e})
        }
    }, Modernizr = function () {
    };
    Modernizr.prototype = c, Modernizr = new Modernizr;
    var f = n.documentElement, u = "svg" === f.nodeName.toLowerCase();
    Modernizr.addTest("placeholder", "placeholder"in i("input") && "placeholder"in i("textarea")), o(), t(l), delete c.addTest, delete c.addAsyncTest;
    for (var p = 0; p < Modernizr._q.length; p++)Modernizr._q[p]();
    e.Modernizr = Modernizr
}(window, document);