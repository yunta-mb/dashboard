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

class ReportDescription extends Backbone.Model

class ReportView extends Backbone.Marionette.ItemView

        template: "report"

        updateView: () =>
                if @model.attributes.data.metadata?
                        if @model.attributes.data.metadata.projector != @last_projector_code
                                @last_projector_code = @model.attributes.data.metadata.projector
                                eval(@model.attributes.data.metadata.projector)
                                $("#report_body").html("&nbsp;")
                                @projector = new @Projector()
                        @projector.update(@model.attributes.data.metadata.data)
                        $("#report_version").html(@model.attributes.data.current_version)
                        $("#report_title").html(@model.attributes.data.metadata.name)


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

        ui: {
                show_all_submissions: "#show_all_submissions"
                show_all_submissions_count: "#submissions_matching_count"
                }

        updateView: () =>
                $(".submission_"+window.API.current_state.submission+"_row").addClass("focused_submission")

                @children.each (report_title) ->
                        report_title.ui.link.attr("href","#"+window.API.compose(report: report_title.model.id)) if report_title.ui?

        onShow: () ->
                @updateView()

        emptyView: ReportListEmpty


#----------------------------------- spinner


class SpinnerView extends Backbone.Marionette.ItemView
        template: "spinner"
        className: 'spinner'



#----------------------------------- faye collection

RemoteObjectMixin = {

        listen: (path) ->
                @faye_path = path
                @current_version = null
                @last_full_request_timestamp = null
                @update_queue = []

                console.log("Listening for list updates: ",@faye_path+"/client/"+window.client_id)

                @full_feed = window.faye.subscribe("/client/"+window.client_id+path, (message) =>
#                        console.log("full data", message)
                        return if @current_version and message.version <= @current_version
                        @set(message.data)
                        @current_version = message.version
                        @metadata = message
                        @apply_updates()
                        )

                @incremental_feed = window.faye.subscribe(path, (message) =>
 #                       console.log("incremental data")
                        @update_queue.push(message)
                        @apply_updates()
                        )

                @refetch_timer = window.setInterval((() =>
                        if (! @current_version) and ( (! @last_full_request_timestamp) or ((new Date().getTime()) - @last_full_request_timestamp > 10000))
                                console.log("not getting full list? re-asking")
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
                                if update.data
                                        @set(update.data)
                                        @metadata.data = update.data
                                if update.projector
                                        @metadata.projector = update.projector
                                if update.name
                                        @metadata.name = update.name
                                @current_version = update.version
                        else
                                console.log("we lost some updates, requesting full set")
                                @request_full()
                @trigger("updated")

        die_mf_die: () ->
                @full_feed.cancel()
                @incremental_feed.cancel()
                window.clearInterval(@refetch_timer)
        }


class RemoteCollection extends Backbone.Collection
        constructor: (params...)->
                super params...
                $.extend(@, RemoteObjectMixin)

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
                @listenTo(@reports, "updated", @reportListView.updateView)
                # d3 - define behaviour
                # faye - start updates

        navigate: (old_state, new_state, changed) ->
#                console.log("con navigate",changed)
                if _.intersection(changed, []).length > 0
                        @submissions.reset()
                        @submissions.fetch()
                else
                        #@submissions_view.updateView()


class ReportController extends Marionette.Controller

        initialize: (options) ->
                @api = options.api
                @listenTo(@api, "navigate", @navigate)
                $(window).resize(@resize)

        navigate: (old_state,new_state,changed) ->
                console.log("rep navigate")
                if _.intersection(changed, ["report"]).length > 0
                        if @reportView
                                @report.die_mf_die()
                                @reportView.close()
                        if new_state.report and new_state.report.length > 0
                                $(".report_row").removeClass("focused_report")
                                @report = new RemoteCollection
                                @report.listen("/report/"+new_state.report)
                                @reportDescription = new ReportDescription({data: @report})
                                @reportView = new ReportView(model: @reportDescription)
                                application.report_region.show(@reportView)
                                @listenTo(@report, "updated", @reportView.updateView)
#                                console.log("x")
#                                application.list_region.show(@reportView)
                        else
                                application.report_region.close()
                else
                        @submissionDetailsView.updateView() if @submissionDetailsView?

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
                list_hidden: false }


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
                ret.replace(/^\//,"")


        parse: (path) ->
                split = path.split("/")
#                console.log("path: ",split)
                new_state = {
                        report: null
                        unfolded_groups: []
                        list_hidden: false }
                i = 0
                while i+1 < split.length
                        key = split[i]
                        value = decodeURIComponent(split[i+1])
                        switch key
                                when "report" then new_state.report = value
                                when "groups" then new_state.unfolded_groups = value.split(",")
                                when "list" then new_state.list_hidden = (value == "hide")
                                else
                                        console.log("stupid key in route: ",key)
                        i += 2
                new_state


        navigate: (inp) ->
                old_state = @current_state #@or {})
                @current_state = _.extend({},old_state,inp)
                application.router.navigate(@compose({}))
                changed = _.filter(_.keys(@current_state), (key) => ( @current_state[key] != old_state[key]) )
#                console.log("cc",old_state,@current_state,changed)
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
        faye_url = 'http://localhost:3001/live' if document.location.hostname == "localhost"
        window.faye = new Faye.Client(faye_url)

        window.pings_missed = 0
        window.faye.subscribe("/ping", (message) =>
                console.log("ping")
                if window.pings_missed > 10
                        $(".ping-fail-overlay").css("display":"none")
                window.pings_missed = 0
                )
        window.ping_check_interval = window.setInterval( (() =>
                window.pings_missed += 1
                if window.pings_missed > 10
                        $(".ping-fail-overlay").css("display":"block")
                ), 1000)


        window.listController = new ListController(api: window.API)
        window.reportController = new ReportController(api: window.API)
        window.listFolderController = new ListFolderController(api: window.API)

        application.start({})

        Backbone.history.start()

        $(".toggle_visibility").live("click", () ->
                window.toggle_visibility("#"+this.id+"_to_hide", "#"+this.id+"_to_show"))

        )
