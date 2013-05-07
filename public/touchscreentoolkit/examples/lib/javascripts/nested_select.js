/*
 * Module containing methods to cater for nested select options.
 * The module expects a select control with tag "<optgroup>" in which case the
 * following happens:
 *      1. We get a collection of each top level child
 *      2. With the top level kids,
 *          a.) if the kid is of type "<option>", we just
 *                  create its node and proceed
 *          b.) if it is of type "<optgroup>", we create the parent node which
 *              has the following behaviours:
 *                  i.) it has the name of the group as its label taken from its
 *                      label attribute
 *                  ii.) initially, all its children are colapsed
 *                  iii.) when it is clicked,
 *                          - all children expanded
 *                          - all children are deselected
 *                        These children correspond to the elements under a
 *                        corresponding source control
 *              The behaviours for this control would also map to standard
 *              behaviours for cases where the source control is a
 *              "multipe select"
 *
 */
var peerGroup = "";

/*function __$(id){
    return document.getElementById(id);
}*/

function nested_select(id, destination){
    peerGroup = "";
    var parent = document.createElement("div");
    parent.style.display = "table";
    parent.style.width = "100%";

    __$(destination).appendChild(parent);

    var row = document.createElement("div");
    row.style.display = "table-row";

    parent.appendChild(row);

    var cell1 = document.createElement("div");
    cell1.style.display = "table-cell";
    cell1.style.verticalAlign = "middle";
    cell1.style.padding = "5px";
    cell1.innerHTML = __$(id).getAttribute("helpText") + "&nbsp;";

    row.appendChild(cell1);

    var row2 = document.createElement("div");
    row2.style.display = "table-row";

    parent.appendChild(row2);

    var cell2 = document.createElement("div");
    cell2.style.display = "table-cell";

    row2.appendChild(cell2);

    var input = document.createElement("input");
    input.id = "tstInputControl";
    input.style.fontSize = "32px";
    input.style.width = "100%";
    input.style.padding = "10px";
    input.style.marginTop = "20px";
    input.style.marginBottom = "20px";

    cell2.appendChild(input);

    var row3 = document.createElement("div");
    row3.style.display = "table-row";

    parent.appendChild(row3);

    var cell3 = document.createElement("div");
    cell3.style.display = "table-cell";

    row3.appendChild(cell3);    

    var container = document.createElement("div");
    container.className = "selectContent";
    container.style.overflow = "auto";

    cell3.appendChild(container);
    
    var select = document.createElement("div")
    select.style.display = "table";
    select.style.width = "100%";
    var multiple = (__$(id).getAttribute("multiple") ? true : false);

    container.appendChild(select);

    var options = __$(id).children;

    for(var i = 0; i < options.length; i++){
        if(options[i].tagName.toUpperCase() == "OPTGROUP"){
            add_opt_group(options[i], select, multiple, i);
        } else {
            add_options([options[i]], select, multiple, false, i);
        }
        if(!multiple){
            peerGroup += "group" + i + "|";
        }
    }

}

function add_opt_group(control, parent, single, groupNumber){
    var multiple = (typeof(single) != "undefined" ? single : false);
    
    var row = document.createElement("div");
    row.style.display = "table-row";

    parent.appendChild(row);
    
    var cell1_1 = document.createElement("div");
    cell1_1.style.display = "table-cell";
    cell1_1.style.verticalAlign = "middle";
    cell1_1.style.padding = "5px";
    cell1_1.style.width = "52px";

    row.appendChild(cell1_1);

    var img = document.createElement("img");
    img.setAttribute("multiple", (multiple ? "true" : "false"));
    img.setAttribute("src", "lib/images/un" + (multiple ? "ticked" : "checked") + ".jpg");
    img.setAttribute("groupNumber", groupNumber);
    img.id = "group" + groupNumber;
    
    img.onclick = function(){
        var multiple = (this.getAttribute("multiple") == "true" ? true : false);
        var colorPartner = this.parentNode.parentNode.getElementsByTagName("div");
        var group = this.getAttribute("groupNumber");

        if(!multiple){
            deselectSection(peerGroup);
        }

        if(this.getAttribute("src").match(/un/)){
            this.setAttribute("src", "lib/images/" + (multiple ? "ticked" : "checked") + ".jpg");
            colorPartner[1].style.backgroundColor = "lightblue";
            __$("groupRow" + group).style.display = "table-row";
        } else {
            this.setAttribute("src", "lib/images/un" + (multiple ? "ticked" : "checked") + ".jpg");
            deselectSection(this.getAttribute("childrenGroup"));

            colorPartner[1].style.backgroundColor = "";
            __$("groupRow" + group).style.display = "none";
        }

    }

    cell1_1.appendChild(img);

    var cell1_2 = document.createElement("div");
    cell1_2.style.display = "table-cell";
    cell1_2.innerHTML = control.label;
    cell1_2.style.verticalAlign = "middle";
    cell1_2.style.padding = "5px";
    cell1_2.style.width = "100%";
    cell1_2.style.borderBottom = "1px solid #ccc";

    cell1_2.onclick = function(){
        var colorPartner = this.parentNode.getElementsByTagName("img");

        colorPartner[0].click();
    }

    row.appendChild(cell1_2);

    var row2 = document.createElement("div");
    row2.style.display = "none";
    row2.id = "groupRow" + groupNumber;

    parent.appendChild(row2);

    var cell2_1 = document.createElement("div");
    cell2_1.style.display = "table-cell";
    cell2_1.innerHTML = "&nbsp;";
    cell2_1.style.width = "52px";

    row2.appendChild(cell2_1);

    var cell2_2 = document.createElement("div");
    cell2_2.style.display = "table-cell";

    row2.appendChild(cell2_2);

    var table = document.createElement("div");
    table.style.display = "table";
    table.style.width = "100%";

    cell2_2.appendChild(table);

    var groupKids = control.children;

    add_options(groupKids, table, single, true, groupNumber);

}

function add_options(groupKids, parent, single, mapToParent, groupNumber){
    var multiple = (typeof(single) != "undefined" ? single : false);
    var parentTag = "";
    
    for(var i = 0; i < groupKids.length; i++){
        if(groupKids[i].innerHTML.trim() == ""){
            continue;
        }
        
        var row = document.createElement("div");
        row.style.display = "table-row";

        parent.appendChild(row);

        var cell1_1 = document.createElement("div");
        cell1_1.style.display = "table-cell";
        cell1_1.style.verticalAlign = "middle";
        cell1_1.style.padding = "5px";
        cell1_1.style.width = "52px";

        row.appendChild(cell1_1);

        var img = document.createElement("img");
        img.setAttribute("multiple", (multiple ? "true" : "false"));
        img.setAttribute("src", "lib/images/un" + (multiple ? "ticked" : "checked") + ".jpg");
        img.setAttribute("groupNumber", groupNumber);
        img.id = (mapToParent == true ? "child" + groupNumber + "_" + i : "group" + groupNumber);
        
        if(mapToParent){
            parentTag += img.id + "|";
        }

        img.onclick = function(){
            var multiple = (this.getAttribute("multiple") == "true" ? true : false);
            var colorPartner = this.parentNode.parentNode.getElementsByTagName("div");

            if(this.getAttribute("src").match(/un/)){
                if(!multiple){
                    if(this.id != "group" + this.getAttribute("groupNumber")){
                        deselectSection(__$("group" + this.getAttribute("groupNumber")).getAttribute("childrenGroup"));
                    } else {
                        deselectSection(peerGroup);
                    }
                }
                
                this.setAttribute("src", "lib/images/" + (multiple ? "ticked" : "checked") + ".jpg");
                colorPartner[1].style.backgroundColor = "lightblue";

                __$("tstInputControl").value += unescape(colorPartner[1].innerHTML) + ";";
                
            } else {
                this.setAttribute("src", "lib/images/un" + (multiple ? "ticked" : "checked") + ".jpg");
                colorPartner[1].style.backgroundColor = "";

                __$("tstInputControl").value = subtract(colorPartner[1].innerHTML + ";");
            }
        }

        cell1_1.appendChild(img);

        var cell1_2 = document.createElement("div");
        cell1_2.style.display = "table-cell";
        cell1_2.innerHTML = groupKids[i].innerHTML;
        cell1_2.style.verticalAlign = "middle";
        cell1_2.style.padding = "5px";
        cell1_2.style.borderBottom = "1px solid #ccc";

        cell1_2.onclick = function(){
            var colorPartner = this.parentNode.getElementsByTagName("img");

            colorPartner[0].click();
        }

        row.appendChild(cell1_2);
    }

    if(mapToParent){
        __$("group" + groupNumber).setAttribute("childrenGroup", parentTag);
    }

}

function deselectSection(group){
    console.log(group);
    var controls = group.split("|");

    for(var i = 0; i < controls.length; i++){
        if(controls[i].trim() != ""){
            if(__$(controls[i])){
                if(!__$(controls[i]).getAttribute("src").match(/un/)){
                    __$(controls[i]).click();
                }
            }
        }
    }
}

function subtract(string){
    var result = __$("tstInputControl").value.replace(string, "");
    return result
}