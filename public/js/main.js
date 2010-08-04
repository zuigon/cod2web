var ShowBoxAutoCount = 0;
function ShowBox(it, box){
	var vis = (box.checked) ? "block" : "none";
	document.getElementById(it).style.display = vis;
}
function ShowBoxRaw(it, box, vis){
	document.getElementById(it).style.display = vis;
}

// jQuery stvari
$.ajaxSetup ({  
	cache: false  
});

function srv_manage(str){
	if (str=="none" || str=="NONE" || str==0 || str==null){ $.cookie("manage_server", "NONE"); }
	else { $.cookie("manage_server", str); }
	location.reload(true);
	return false;
}

function srv_novi(){
	// forma za novi server
}

function srv_start(){
}

function srv_stop(){
}
