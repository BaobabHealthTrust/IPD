(function () {

    "use strict"

    var mPopupOn = false;

    var mPopupTimer;

    var close = "data:image/png;base64,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";

    var info = "data:image/png;base64,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";

    function __$(id) {

        return document.getElementById(id);

    }

    function checkCtrl(obj) {
        var o = obj;
        var t = o.offsetTop;
        var l = o.offsetLeft + 1;
        var w = o.offsetWidth;
        var h = o.offsetHeight;

        while ((o ? (o.offsetParent != document.body) : false)) {
            o = o.offsetParent;
            t += (o ? o.offsetTop : 0);
            l += (o ? o.offsetLeft : 0);
        }
        return [w, h, t, l];
    }

    function init() {

        var img = document.createElement("img");
        img.id = "btnHelp";
        img.style.position = "absolute";
        img.style.right = "10px";
        img.style.top = "10px";
        img.style.zIndex = 1002;
        img.style.cursor = "pointer";
        img.setAttribute("height", 60);
        img.setAttribute("src", info);

        document.body.appendChild(img);

        attachOnClickEvent();

    }

    function attachOnClickEvent() {

        if (__$("btnHelp")) {

            __$("btnHelp").onclick = function () {

                if (!mPopupOn) {

                    __$("btnHelp").setAttribute("src", close);

                    mPopupOn = true;

                    displayPopup();

                } else {

                    __$("btnHelp").setAttribute("src", info);

                    mPopupOn = false;

                    hidePopup();

                }

            }

        }

    }

    function displayPopup() {

        if (!__$("__popup")) {

            buildPopup();

        }

        mPopupTimer = setInterval(
            function () {
                resizeDiv()
            }, 10);

        __$("__popup").style.display = "block";

    }

    function hidePopup() {

        if (__$("__popup")) {

            document.body.removeChild(__$("__popup"));

        }

        clearInterval(mPopupTimer);

    }

    function resizeDiv() {

        if (__$("cell1") && __$("__popup") && __$("cell2")) {

            var pos = checkCtrl(__$("__popup"));

            __$("cell1").style.height = (pos[1] - 17) + "px";

            __$("cell2").style.height = (pos[1] - 17) + "px";

        }

    }

    function buildPopup() {

        // [w, h, t, l]

        var pos = checkCtrl(__$("btnHelp"));

        var div = document.createElement("div");
        div.id = "__popup";
        div.style.display = "block";
        div.style.position = "absolute";
        div.style.width = "75%";
        div.style.zIndex = 1000;
        div.style.height = "65%";
        div.style.border = "1px solid #345db5";
        div.style.backgroundColor = "#fff";
        div.style.top = (pos[2] + (pos[1] / 2) + 10) + "px";
        div.style.right = (window.innerWidth - pos[3] - (pos[0] / 2) + 10) + "px";
        div.style.boxShadow = "10px 10px 5px #888888";
        div.style.padding = "5px";

        document.body.appendChild(div);

        var table = document.createElement("table");
        table.style.width = "100%";
        table.border = 1;
        table.style.borderCollapse = "collapse";

        div.appendChild(table);

        var tr = document.createElement("tr");

        table.appendChild(tr);

        var td1 = document.createElement("td");
        td1.style.width = "80%";

        tr.appendChild(td1);

        var td2 = document.createElement("td");
        td2.style.width = "20%";

        tr.appendChild(td2);

        var cell1 = document.createElement("div");
        cell1.id = "cell1";
        cell1.style.width = "100%";
        cell1.style.backgroundColor = "#333";

        td1.appendChild(cell1);

        var cell2 = document.createElement("div");
        cell2.id = "cell2";
        cell2.style.width = "100%";
        cell2.style.overflow = "auto";

        td2.appendChild(cell2);

        var video = document.createElement("video");
        video.id = "video";
        video.setAttribute("controls", true);
        video.style.width = "100%";
        video.style.height = "100%";

        cell1.appendChild(video);

        if(typeof(helpLinks) !== "undefined") {

            var keys = Object.keys(helpLinks);

            var ul = document.createElement("ul");
            ul.style.listStyle = "none";
            ul.style.width = "100%";
            ul.style.padding = "0px";

            cell2.appendChild(ul);

            for(var i = 0; i < keys.length; i++) {

                var li = document.createElement("li");
                li.innerHTML = keys[i];

                li.setAttribute("base", helpLinks[keys[i]]);

                li.style.padding = "10px";

                li.style.cursor = "pointer";

                li.onmouseover = function() {

                    this.style.backgroundColor = "lightblue";

                }

                li.onmouseout = function() {

                    this.style.backgroundColor = "";

                }

                li.onclick = function() {

                    setupVideo(document.getElementById("video"), this.getAttribute("base"));

                }

                ul.appendChild(li);

            }

        }

    }

    function setupVideo(parent, videoName) {

        if(!parent || !videoName) {

            return;

        }

        // Test for support
        if (parent.canPlayType("video/ogg")) {

            parent.setAttribute("src", videoName + ".ogg");

        } else if (parent.canPlayType("video/webm")) {

            parent.setAttribute("src", videoName + ".webm");

        }
        else if (parent.canPlayType("video/mp4")) {

            parent.setAttribute("src", videoName + ".mp4");

        } else {

            window.alert("Can't play anything");

        }

        parent.load();
        parent.play();
    }

    init();

})();