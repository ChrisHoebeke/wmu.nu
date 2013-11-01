 (function() {
   
   Maritime.Schedule = (function() {
    $.getJSON( "/today", function( data ) {
      $.each( data, function( key, val ) {
        var stime = new Date(val.start.dateTime);
        var etime = new Date(val.end.dateTime);
        
        var startTime = stime.getHours() + ":" + (stime.getMinutes()<10?'0':'') + stime.getMinutes(); 
        var endTime = etime.getHours() + ":" + (etime.getMinutes()<10?'0':'') + etime.getMinutes(); 
        
        var room = val.location.replace("Classrooms-", "");
        
        $("#calendar tbody").append("<tr><td>" + startTime + " - " + endTime + "</td><td>" + val.summary + "</td><td>" +  room  + "</td></tr>");
      });
    });
  });
   
 }).call(this);