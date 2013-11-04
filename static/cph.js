(function() {
   
   Maritime.Cph = (function() {
     $('#cph table').remove();
     var target = document.getElementById('spinner')
     var spinner = new Spinner().spin(target);
    $.get( "/cph", function( data ) {
      $('.cph').append(data);
      $('.spinner').remove();
     });  
  });
   
 }).call(this);