 (function() {
   
   Maritime.Schedule = (function() {
   
     now  = moment();
     then = moment(parseInt( $('#campus').attr('data-time')))
     console.log(now.diff(then, "minutes"));
     if ( now.diff(then, "minutes") > 30 ) {     
       $('#campus-events').hide();
       $("#campus-events tbody tr").remove();
       var target = document.getElementById('spinner')
       var spinner = new Spinner().spin(target);
      $.getJSON( "/today", function( data ) {
        $.each( data, function( key, val ) {
          var stime = new Date(val.start.dateTime);
          var etime = new Date(val.end.dateTime);
        
          var startTime = stime.getHours() + ":" + (stime.getMinutes()<10?'0':'') + stime.getMinutes(); 
          var endTime = etime.getHours() + ":" + (etime.getMinutes()<10?'0':'') + etime.getMinutes(); 
        
          var room = val.location.replace("Classrooms-", "");
        
          $("#campus-events tbody").append("<tr><td>" + startTime + " - " + endTime + "</td><td>" + val.summary + "</td><td>" +  room  + "</td></tr>");
          $('.spinner').remove();
           $('#campus-events').show();
        });
      });
      $('#campus').attr('data-time', moment() );
    }
  });
   
 }).call(this);