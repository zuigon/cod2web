var ShowBoxAutoCount = 0;
function ShowBox(it, box){
	var vis = (box.checked) ? "block" : "none";
	document.getElementById(it).style.display = vis;
}
function ShowBoxRaw(it, box, vis){
	document.getElementById(it).style.display = vis;
}
