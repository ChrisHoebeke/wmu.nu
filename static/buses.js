 (function() {
   Maritime.Buses = (function() {
     $('table.buses').hide();
     $(".present table.buses tbody tr").remove();
     var target = document.getElementById('spinner')
     var spinner = new Spinner().spin(target);
     
     var stopId = $('.present .buses').attr('data-id');
     var url = "/buses?stopId=" + stopId;
     console.log(url)
     $.getJSON(  url, function( data ) {
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
         $(".present table.buses tbody").append("<tr><td>" +  line + "</td><td>" + terminus + "</td><td>" + time.format('HH:mm') + "</td><td>" + status + "</td></tr>");
         $('.spinner').remove();
         $('table.buses').show();
       });
     });
   });
   
}).call(this);