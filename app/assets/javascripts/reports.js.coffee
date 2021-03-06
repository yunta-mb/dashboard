# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/


#----------------------------------- common

window.toggle_visibility = (to_hide,to_show) ->
        $(to_hide).hide()
        $(to_show).show()
        false


#----------------------------------- templating


Backbone.Marionette.Renderer.render = (template, data) ->
        if template instanceof Array
                template_name = template[0]
                extra_data = template[1]
        else
                template_name = template
                extra_data = {}
        if !JST[template_name]
                console.log(JST)
                throw "Template '" + template_name + "' not found!"
        return JST[template_name]($.extend({},data,extra_data))


#----------------------------------- report

class ReportView extends Backbone.Marionette.ItemView

        template: "report"

        updateView: () =>
                if @model.current_version
                        if @model.attributes.projector != @last_projector_code
                                @last_projector_code = @model.attributes.projector
                                $("#report_body").html("")
                                try
                                        eval(@model.attributes.projector)
                                        @projector = new @Projector()
                                catch e
                                        console.log("Projector evaluation or construction error", e.message, e.lineNumber)
                        try
                                @projector.update(@model.attributes.data)
                        catch e
                                console.log("Projector update error", e.message, e.lineNumber)
                        date = new Date(@model.current_timestamp)
                        $("#report_timestamp").html(date.getFullYear() + "-" + ("0"+(date.getMonth()+1)).slice(-2) + "-" + ("0"+date.getDate()).slice(-2) + " " + ("0" + date.getHours()).slice(-2) + ":" + ("0" + date.getMinutes()).slice(-2) + ":" + ("0"+date.getSeconds()).slice(-2))
                        window.timelineController.set_current_report_date(date)


#----------------------------------- report list

class ReportTitle extends Backbone.Model


class ReportTitleView extends Backbone.Marionette.ItemView
        template: "report_title"
        tagName: 'li'
        className: () -> "report_title report_"+@model.id+"_title"
        modelEvents: {
                "change": (x) -> @render() }
        ui: {
                link: "a" }


class ReportListEmpty extends Backbone.Marionette.ItemView
        tagName: 'tr'
        template: "report_list_empty"


class ReportListView extends Backbone.Marionette.CompositeView
        tagName: "div"
        className: "report_list_view"
        template: "report_list"
        itemView: ReportTitleView

        appendHtml: (collection_view, item_view) ->
                collection_view.$("ul").append(item_view.el)

        updateView: () =>
                $(".report_title").removeClass("focused_report")
                $(".report_title").blur()
                $(".report_"+window.API.current_state.report+"_title").addClass("focused_report")

                @children.each (report_title) ->
                        report_title.ui.link.attr("href",window.API.compose(report: report_title.model.id, date: null, version: null, view: null)) if report_title.ui?

        onShow: () ->
                @updateView()

        emptyView: ReportListEmpty

        redraw: () =>
                @render()
                @updateView()

#----------------------------------- spinner


class SpinnerView extends Backbone.Marionette.ItemView
        template: "spinner"
        className: 'spinner'



#----------------------------------- faye-backbone model & collection

RemoteObjectMixin = {

        subscribe: (path) ->
                @faye_path = path
                @current_version = null
                @last_full_request_timestamp = null
                @update_queue = []
                @current_timestamp = null

                console.log("Listening for list updates: ",@faye_path+"/client/"+window.client_id)

                window.faye.publish("/subscriptions/continue", client: window.client_id, path: @faye_path)

                @full_feed = window.faye.subscribe("/client/"+window.client_id+path, (message) =>
#                        console.log("full data", @, this)
                        console.log("full data", message.timestamp, message.version)
                        return if @current_version and message.version <= @current_version
                        @state_set(message.state)
                        @current_version = message.version
                        @current_timestamp = message.timestamp
                        @apply_updates()
                        )

                @incremental_feed = window.faye.subscribe(path, (message) =>
                        @update_queue.push(message)
                        @apply_updates()
                        )

                @maintenance_timer = window.setInterval((() =>
                        window.faye.publish("/subscriptions/continue", client: window.client_id, path: @faye_path)
                        if (! @current_version) and ( (! @last_full_request_timestamp) or ((new Date().getTime()) - @last_full_request_timestamp > 10000))
                                console.log("didn't get full data in 10s, re-asking")
                                @request_full()
                        ), 10000)

                @request_full()


        request_full: () ->
                @current_version = null
                @last_full_request_timestamp = new Date().getTime()
                window.faye.publish("/requests", client: window.client_id, requesting: @faye_path)

        apply_updates: () ->
                return if ! @current_version
                while @update_queue.length > 0
                        update = @update_queue.shift()
                        continue if update.version <= @current_version
                        if update.version == @current_version + 1
                                @state_update(update.update) if update.update
                                @state_set(update.state) if update.state
                                @current_version = update.version
                                @current_timestamp = update.timestamp
                        else if update.state?
                                @state_set(update.state)
                                @current_version = update.version
                                @current_timestamp = update.timestamp
                        else
                                console.log("we lost some updates, requesting full data.",@current_version, update.version)
                                @request_full()
                @trigger("updated")

        unsubscribe: () ->
                if @faye_path
                        @full_feed.cancel()
                        @incremental_feed.cancel()
                        window.clearInterval(@maintenance_timer)
                        window.faye.publish("/subscriptions/discontinue", client: window.client_id, path: @faye_path)
                        @faye_path = null

        }


class RemoteCollection extends Backbone.Collection

        constructor: (params...)->
                $.extend(@, RemoteObjectMixin)
                super params...

        state_set: (new_state) ->
                @set(new_state)


class RemoteModel extends Backbone.Model

        constructor: (params...)->
                $.extend(@, RemoteObjectMixin)
                super params...

        state_set: (new_state) ->
                @set(new_state)

#----------------------------------- controllers

class ListController extends Marionette.Controller

        initialize: (options) ->
                @api = options.api
                @listenTo(@api, "navigate", @navigate)
                @reports = new RemoteCollection
                @reports.subscribe("/reports")
                @reportListView = new ReportListView
                @reportListView.collection = @reports
                application.list_region.show(@reportListView)
                @listenTo(@reports, "updated", @reportListView.redraw)

        navigate: (old_state, new_state, changed) ->
                @reportListView.updateView()


class ReportController extends Marionette.Controller

        initialize: (options) ->
                @api = options.api
                @listenTo(@api, "navigate", @navigate)
                $(window).resize(@resize)

        navigate: (old_state,new_state,changed) ->
                if _.intersection(changed, ["report","date","version"]).length > 0
                        if @report?
                                @stopListening(@report)
                                @report.unsubscribe()
                                @reportView.close() if @reportView?
                        if new_state.report and new_state.report.length > 0
                                $(".report_row").removeClass("focused_report")
                                path = "/report/"+new_state.report
                                if new_state.date? and new_state.date
                                        path += "/date/"+new_state.date
                                if new_state.version? and new_state.version
                                        path += "/version/"+new_state.version
                                @report = new RemoteModel
                                @report.subscribe(path)
                                @reportView = new ReportView(model: @report)
                                application.report_region.show(@reportView)
                                @listenTo(@report, "updated", @reportView.updateView)
                        else
                                application.report_region.close()
                else
                        if _.intersection(changed, ["view"]).length > 0
                                @reportView.updateView()

        resize: () =>
                @reportView.updateView() if @reportView?

        current_is_live: () ->
                (not (window.API.current_state.date? and window.API.current_state.date)) and (not (window.API.current_state.version? and window.API.current_state.version))


class ListFolderController extends Marionette.Controller

        initialize: (options) ->
                @api = options.api
                @listenTo(@api, "navigate", @navigate)

        navigate: (old_state,new_state,changed) ->
                if new_state.list_hidden
                        els = $(".list_unfolded")
                        els.removeClass("list_unfolded")
                        els.addClass("list_folded")
                else
                        els = $(".list_folded")
                        els.removeClass("list_folded")
                        els.addClass("list_unfolded")
                window.reportController.resize() if _.intersection(changed, ["list_hidden"]).length > 0
                $("#list_switch_link").attr("href", @api.compose(list_hidden: (not @api.current_state.list_hidden)))


class DemoController extends Marionette.Controller

        initialize: (options) ->
                @api = options.api
                @listenTo(@api, "navigate", @navigate)
                @interval = false

        show_next_report: () =>
#                console.log("switching report",window.listController.reports)
                current_index = window.listController.reports.models.indexOf(window.listController.reports.get(@api.current_state.report or 1))
                new_index = (current_index + 1) % window.listController.reports.models.length
                @api.navigate(report: window.listController.reports.models[new_index].id.toString(), view: null)

        navigate: (old_state,new_state,changed) ->
                if _.intersection(changed, ["demo"]).length > 0
                        clearInterval(@interval) if @interval
                        if new_state.demo
                                @interval = window.setInterval(@show_next_report,parseInt(new_state.demo)*1000)

class TimelineController extends Marionette.Controller

        initialize: (options) ->
                @api = options.api
                @listenTo(@api, "navigate", @navigate)
                $(window).resize(@repaint)
                @date = null
                @timeline_repainting = false
                @repaint()

        navigate: (old_state,new_state,changed) ->
                if _.intersection(changed, ["report","date","list_hidden"]).length > 0
                        @repaint()

        set_current_report_date: (@date) =>
                d3.select("#report_details_big svg circle")
                        .attr("cx",@scale(@date))

        repaint: () =>
                now = new Date()
                @scale = d3.time.scale().domain([new Date(now - 60 * 60 * 24 * 365 * 1000), now]).range([20,$("#report_details_big").width() - 26])
                month_axis = d3.svg.axis()
                        .scale(@scale)
                        .orient("bottom")
                        .ticks(d3.time.months, 1)
                        .tickFormat(d3.time.format("%B"))
                        .tickSize(6,2)

                year_axis = d3.svg.axis()
                        .scale(@scale)
                        .orient("bottom")
                        .ticks(d3.time.years, 1)
                        .tickFormat(d3.time.format("%Y"))
                        .tickSize(6,0)

                d3.select("#report_details_big svg .months").attr("transform", "translate(0,5)").call(month_axis)
                d3.select("#report_details_big svg .years").attr("transform", "translate(0,25)").call(year_axis)

                circle = d3.select("#report_details_big svg circle")
                        .attr("r","5px")
                        .attr("cx",(if @date then @scale(@date) else -100))
                        .attr("cy","6px")
                        .classed("live", window.reportController.current_is_live())

                input_overlay = d3.select("#report_details_big svg .input_overlay")
                        .attr("x","0")
                        .attr("y","0")
                        .attr("width",$("#report_details_big").width())
                        .attr("height",$("#report_details_big").height())
                        .style("cursor","crosshair")
                        .on("click",() ->
                                window.timelineController.timeline_repainting = true
                                x = d3.mouse(this)[0]
                                if x > $("#report_details_big").width() - 30
                                        window.API.navigate(date: null, version: null)
                                else
                                        window.API.navigate(date: window.timelineController.scale.invert(x).getTime(), version: null))


                if @api.current_state.date
                        $("#report_details_big").show()

                $("#report_details_wrapper").on('mouseenter', (event) =>
                        if @timeline_repainting
                                $("#report_details_big").show()
                        else
                                $("#report_details_big").show()
                        @timeline_repainting = false
                        )

                $("#report_details_wrapper").on('mouseleave', (event) ->
                        if not window.API.current_state.date
                                $("#report_details_big").hide() #'fast')
                        )


class KeyboardController extends Marionette.Controller

        initialize: (options) ->
                @api = options.api
                $(document).on("keyup", (e) ->
                        delta = switch e.key
                                when "Left" then -1
                                when "Right" then 1
                                when "Up" then 1
                                when "Down" then -1
                                else 0
                        return if delta == 0
                        return if not window.reportController.report?
                        switch e.key
                                when "Up", "Down"
                                        current_version = parseInt(window.API.current_state.version or window.reportController.report.current_version)
                                        return if not current_version
                                        new_version = current_version + delta
                                        return if new_version < 1 or (window.reportController.current_is_live() and delta > 0)
                                        window.API.navigate(date: null, version: new_version)
                                when "Left", "Right"
                                        current_timestamp = if window.API.current_state.date? and window.API.current_state.date
                                                new Date(parseInt(window.API.current_state.date))
                                        else
                                                new Date(window.reportController.report.current_timestamp)
                                        new_timestamp = new Date(current_timestamp.getTime() + delta * 24*3600*1000)
                                        window.API.navigate(date: new_timestamp.getTime(), version: null)
                        )


#----------------------------------- router


application = new Backbone.Marionette.Application()
application.addRegions(
        list_region: "#list_region"
        report_region: "#report_region"
        )



class API

        current_state: {
                report: undefined
                unfolded_groups: []
                list_hidden: false
                demo: false
                date: undefined
                version: undefined
                view: undefined }


        constructor: () ->
                _.extend(@, Backbone.Events)


        compose: (mod) ->
                data = $.extend({},@current_state,mod)
                ret = "/a"
                if data.report?
                        ret += "/report/"+data.report
                if data.unfolded_groups? and data.unfolded_groups.length > 0
                        ret += "/groups/"+data.unfolded_groups
                if data.list_hidden
                        ret += "/list/hide"
                if data.demo? and data.demo
                        ret += "/demo/"+data.demo
                if data.date? and data.date
                        ret += "/date/"+data.date
                if data.version? and data.version
                        ret += "/version/"+data.version
                if data.view? and data.view
                        ret += "/view/"+data.view
                if /[^\/]*:\/\/[^\/\#]*\#/.test(window.location)
                        ret.replace(/^\//,"#")
                ret

        parse: (path) ->
                split = path.split("/")
#                console.log("path: ",split)
                new_state = {
                        report: null
                        unfolded_groups: []
                        list_hidden: false
                        demo: false
                        date: null
                        version: null
                        view: null }
                i = 0
                while i+1 < split.length
                        key = split[i]
                        value = decodeURIComponent(split[i+1])
                        switch key
                                when "report" then new_state.report = value
                                when "groups" then new_state.unfolded_groups = value.split(",")
                                when "list" then new_state.list_hidden = (value == "hide")
                                when "demo" then new_state.demo = value
                                when "date" then new_state.date = value
                                when "version" then new_state.version = value
                                when "view" then new_state.view = value
                                else
                                        console.log("stupid key in route: ",key)
                        i += 2
                new_state


        navigate: (inp) ->
                $(":focus").blur()
                old_state = @current_state #@or {})
                @current_state = _.extend({},old_state,inp)
                application.router.navigate(@compose({}))
                changed = _.filter(_.keys(@current_state), (key) => ( @current_state[key] != old_state[key]) )
                #console.log("cc",old_state,@current_state,changed)
                @trigger("navigate",old_state,@current_state,changed)


        root: () ->
                @subrouting_a("")


        subrouting_a: (path) ->
                path = "" if not path?
                @navigate(@parse(path))



window.API = new API()

Router = Marionette.AppRouter.extend(

        appRoutes: {
                "": "root",
                "a(/*path)": "subrouting_a"
                },

        controller: window.API
        )



application.addInitializer( (options) ->
        application.router = new Router()
        )



$(document).ready( () ->

        window.client_id = '0/'
        for i in [0..15]
                window.client_id += Math.floor(Math.random()*16).toString(16)

        faye_url = '/live'
        faye_url = 'http://localhost:3001/live' if document.location.hostname == "localhost" or document.location.hostname == "127.0.0.1"
        window.faye = new Faye.Client(faye_url, timeout: 30)
        window.faye.disable("eventsource")

        window.pings_missed = 0
        window.faye.subscribe("/ping", (message) =>
                if window.pings_missed > 10
                        $(".ping-fail-overlay").css("display":"none")
                window.pings_missed = 0
                )
        window.ping_check_interval = window.setInterval( (() =>
                window.pings_missed += 1
                if window.pings_missed > 10
                        $(".ping-fail-overlay").css("display":"block")
                ), 1000)

        #window.faye.on('transport:down', () -> console.log("transport:down"))
        #window.faye.on('transport:down', () -> console.log("transport:up"))

        window.listController = new ListController(api: window.API)
        window.reportController = new ReportController(api: window.API)
        window.listFolderController = new ListFolderController(api: window.API)
        window.demoController = new DemoController(api: window.API)
        window.timelineController = new TimelineController(api: window.API)
        window.keyboardController = new KeyboardController(api: window.API)

        application.start({})

        Backbone.history.start({pushState: true})


        $(document).on('click', 'a', (event) ->
                if not event.currentTarget.pathname.substr(0,4) == "http"
                        event.preventDefault()
                        Backbone.history.navigate(event.currentTarget.pathname, trigger: true))

        $(".toggle_visibility").live("click", () ->
                window.toggle_visibility("#"+this.id+"_to_hide", "#"+this.id+"_to_show"))

        )
