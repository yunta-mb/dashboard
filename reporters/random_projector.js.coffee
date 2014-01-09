class @Projector
        update: (data) ->
                if not @svg?
                        @svg = d3.select("#report_body").append("svg").attr("id","timeline").attr("width", 500).attr("height", 400)
                        @circle_group = @svg.append("g").attr("id","main")

                console.log(data)
                dots = @circle_group.selectAll("circle").data(data, (d)->d.id)

                dots.enter()
                        .append("circle")
                        .attr("r", (d,i) -> 1 + d.value * 10)
                        .attr("fill", (d,i) -> "red")

                dots
                        .attr("cx", (d,i) -> 20*i)
                        .attr("cy", (d,i) -> d.value*200)

                dots.exit()
                        .remove()
