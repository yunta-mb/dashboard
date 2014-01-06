class @Projector
        update: (data) ->
                if $("#timeline").length > 0
                        svg = d3.select("#timeline")
                        circle_group = svg.select("#main")
                else
                        svg = d3.select("#report_body").append("svg").attr("id","timeline").attr("width", 500).attr("height", 400)
                        circle_group = svg.append("g").attr("id","main")

                dots_enter = circle_group.selectAll("circle").data(data).enter().append("circle")
                dots_enter.attr("cx", (d,i) -> 4*i)
                        .attr("cy", (d,i) -> 4*i)
                        .attr("r", (d,i) -> 2)
                        .attr("fill", (d,i) -> "red")
