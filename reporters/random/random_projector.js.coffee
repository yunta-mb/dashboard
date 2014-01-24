class @Projector

        html_template: `<%= skim("random_projector.html.skim") %>`
        css: <%= sass('random_projector.css.sass').inspect %>

        constructor: () ->
                $("#report_body").append(@html_template.call(@,{}))
                $("#report_body").append("<style type=\"text/css\">"+@css+"</style>")

        update: (data) ->

                dots = d3.select("#timeline").selectAll("circle").data(data.sequence, (d)->d.id)

                dots.enter()
                        .append("circle")
                        .attr("r", (d,i) -> 1 + d.value * 10)
                        .attr("fill", (d,i) -> "green")

                dots
                        .attr("cx", (d,i) -> $("#report_region").width()*i/40)
                        .attr("cy", (d,i) -> d.value*400)

                dots.exit()
                        .remove()
