
function goToNext() {
  var next = document.querySelector("li[class = 'active'] + li > a");
  if ( next === undefined ) { 
    next = document.querySelector("li > a");
  }
  next.click();
}

function looper() {  window.setInterval( function() { goToNext(); }, 10000)}
looper(); 
