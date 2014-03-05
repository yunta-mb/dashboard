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
                        $("#report_version").html(@model.current_version)


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
                        report_title.ui.link.attr("href","#"+window.API.compose(report: report_title.model.id)) if report_title.ui?

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

        listen: (path) ->
                @faye_path = path
                @current_version = null
                @last_full_request_timestamp = null
                @update_queue = []

                console.log("Listening for list updates: ",@faye_path+"/client/"+window.client_id)

                @full_feed = window.faye.subscribe("/client/"+window.client_id+path, (message) =>
#                        console.log("full data", @, this)
                        return if @current_version and message.version <= @current_version
                        @state_set(message.state)
                        @current_version = message.version
                        @apply_updates()
                        )

                @incremental_feed = window.faye.subscribe(path, (message) =>
                        @update_queue.push(message)
                        @apply_updates()
                        )

                @refetch_timer = window.setInterval((() =>
                        if (! @current_version) and ( (! @last_full_request_timestamp) or ((new Date().getTime()) - @last_full_request_timestamp > 10000))
                                console.log("didn't get full data in 10s, re-asking")
                                @request_full()
                        ), 10000)

                @request_full()


        request_full: () ->
                @current_version = null
                @last_full_request_timestamp = new Date().getTime()
                window.faye.publish("/requests", { client: window.client_id, requesting: @faye_path  })

        apply_updates: () ->
                return if ! @current_version
                while @update_queue.length > 0
                        update = @update_queue.shift()
                        continue if update.version <= @current_version
                        if update.version == @current_version + 1
                                @state_update(update.update) if update.update
                                @state_set(update.state) if update.state
                                @current_version = update.version
                        else if update.state?
                                @state_set(update.state)
                                @current_version = update.version
                        else
                                console.log("we lost some updates, requesting full data.",@current_version, update.version)
                                @request_full()
                @trigger("updated")

        die_mf_die: () ->
                @full_feed.cancel()
                @incremental_feed.cancel()
                window.clearInterval(@refetch_timer)

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
                @reports.listen("/reports")
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
                if _.intersection(changed, ["report"]).length > 0
                        if @report?
                                @stopListening(@report)
                                @report.die_mf_die()
                                @reportView.close() if @reportView?
                        if new_state.report and new_state.report.length > 0
                                $(".report_row").removeClass("focused_report")
                                @report = new RemoteModel
                                @report.listen("/report/"+new_state.report)
                                @reportView = new ReportView(model: @report)
                                application.report_region.show(@reportView)
                                @listenTo(@report, "updated", @reportView.updateView)
                        else
                                application.report_region.close()

        resize: () =>
                @reportView.updateView() if @reportView?


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
                $("#list_switch_link").attr("href", "#"+@api.compose(list_hidden: (not @api.current_state.list_hidden)))


class DemoController extends Marionette.Controller

        initialize: (options) ->
                @api = options.api
                @listenTo(@api, "navigate", @navigate)
                @interval = false

        show_next_report: () =>
#                console.log("switching report",window.listController.reports)
                current_index = window.listController.reports.models.indexOf(window.listController.reports.get(@api.current_state.report or 1))
                new_index = (current_index + 1) % window.listController.reports.models.length
                @api.navigate(report: window.listController.reports.models[new_index].id.toString())

        navigate: (old_state,new_state,changed) ->
                if _.intersection(changed, ["demo"]).length > 0
                        clearInterval(@interval) if @interval
                        if new_state.demo
                                @interval = window.setInterval(@show_next_report,parseInt(new_state.demo)*1000)


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
                demo: false }


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
                ret.replace(/^\//,"")


        parse: (path) ->
                split = path.split("/")
#                console.log("path: ",split)
                new_state = {
                        report: null
                        unfolded_groups: []
                        list_hidden: false
                        demo: false }
                i = 0
                while i+1 < split.length
                        key = split[i]
                        value = decodeURIComponent(split[i+1])
                        switch key
                                when "report" then new_state.report = value
                                when "groups" then new_state.unfolded_groups = value.split(",")
                                when "list" then new_state.list_hidden = (value == "hide")
                                when "demo" then new_state.demo = value
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
        window.faye = new Faye.Client(faye_url, timeout: 60)
        window.faye.disable("websocket")

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

        application.start({})

        Backbone.history.start()

        $(".toggle_visibility").live("click", () ->
                window.toggle_visibility("#"+this.id+"_to_hide", "#"+this.id+"_to_show"))

        )
