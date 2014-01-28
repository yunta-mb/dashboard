class @Projector

        html_template: `<%= skim("community_projector.html.skim") %>`
        css: <%= sass('community_projector.css.sass').inspect %>

        constructor: () ->
                $("#report_body").append(@html_template.call(@,{}))
                $("#report_body").append("<style type=\"text/css\">"+@css+"</style>")

        update: (data) ->

                now = new Date()
                time_scale = d3.time.scale().domain([new Date(now - 60 * 60 * 4 * 1000), now]).range([0,$("#report_region").width()])
                for d in data.recent_activity
                        d.x = time_scale(new Date(d.timestamp))

                recent_activity = ( activity for activity in data.recent_activity when activity.x > 0 )

                block_width = 30
                for activity, i in recent_activity
                        if not activity.y
                                y = 0
                                free = false
                                while free == false
                                        free = true
                                        for j in [0..i]
                                                if (recent_activity[j].y == y) and (recent_activity[j].x < (activity.x+block_width)) and ((recent_activity[j].x + block_width) > activity.x)
                                                        y++
                                                        free = false
                                                        break
                                activity.y = y

                max_y_location = d3.max(recent_activity, (d) -> d.y)
                d3.select("#timeline").style("heigth", (50 + max_y_location * 16) + "px")

                max_magnitude = d3.max(recent_activity, (d) -> d.magnitude)
                r_scale = d3.scale.pow().domain([1,max_magnitude]).range([5.0,block_width/2 - 1.0 ])

                x_axis = d3.svg.axis()
                        .scale(time_scale)
                        .orient("top")
                        .ticks(d3.time.minutes, 60)
                        .tickFormat(d3.time.format("%H:%M"))
                        .tickSize(6,2)

                x_axis_g = d3.select("#timeline .x-axis").attr("transform", "translate(0,30)").call(x_axis)


                color = (system) -> (()->{ twitter: "#0000FF" })()[system] #fuck js and fuck coffeescript

                dots = d3.select("#timeline .x-axis").attr("transform", "translate(-40,35)").selectAll(".activity").data(recent_activity, (d)->d.id)

                dots_enter = dots.enter().append("g").attr("class","activity").on("click",(d) -> window.open(d.url, '_blank')).style("cursor","pointer")
                dots_enter.append("circle")
                        .attr("stroke-width",1)
                        .attr("stroke","black")
                        .attr("opacity",0.5)
                        .attr("fill", (d,i) -> color(d.system))

                dots
                        .attr("transform", (d,i) => "translate("+d.x+","+(15 + d.y*20)+")")
                        .select("circle")
                        .attr("r",(d) -> r_scale(d.magnitude) - 1.0)

                dots.exit()
                        .remove()
