 (function() {
   Maritime.Buses = (function() {
     $.getJSON( "/buses", function( data ) {
       $.each( data, function( key, val ) {
          line = val.line;
          terminus = val.terminus;
          time = moment(val.time);
          delay = val.delay
          if ( delay == 0 ) {
            arr = time.fromNow();
            status = "(On Time)";    
          } else { 
            arr = time.add('minutes', delay).fromNow();
            status = "(Delayed " + delay + " minues)";             
          }
         status = arr + " " + status;
         $("#buses tbody").append("<tr><td>" +  line + "</td><td>" + terminus + "</td><td>" + time.format('HH:mm') + "</td><td>" + status + "</td></tr>");
       });
     });
   });
   
}).call(this);