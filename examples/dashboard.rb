# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  gem 'p2', path: '.'
  gem 'benchmark-ips', '>= 2.14.0'
  gem 'json'
end

require 'p2'
require 'benchmark/ips'
require 'json'

# The following is an example of a dashboard-type SPA app, extracted from an
# actual working app. This example demonstrates the usage of template
# composition, which allows putting separate parts of the markup in separate
# templates, then composing them into a whole page.
# 
# This example also demonstrates the use of extensions to abstract away chunks
# of markup ("partials") dedicated to lower-level markup, such as an import map,
# or a select input element with options.
#
# The code for the markup is organised under a module. All so-called "partials"
# are defined as constants and are easily distinguishable from normal tags, or
# extensions by their case.
# 
# It's all just procs, easily composed, a simple API, minimal boilerplate, and
# fast: on a decent development machine, the entire page is rendered in about
# 30µs, or about 30,000 times per second.

P2.extension(
  import_map: ->(map) {
    script(type: 'importmap') {
      raw map.to_json
    }
  },
  script_module: ->(js) {
    script(type: 'module') { raw js }
  },
  select_with_options: ->(options:, **props) {
    select(**props) {
      options.each { |v, t|
        option(t, value: v)
      }
    }
  }
)

module Dashboard
  IMPORT_MAP_JSON = {
    'imports' => {
      "vendor/d3"           =>  "https://cdn.jsdelivr.net/npm/d3@7/+esm",
      "lib/alerts"          =>  "/app/js/lib/alerts.js",
      "lib/barchart"        =>  "/app/js/lib/barchart.js",
      "lib/browser_history" =>  "/app/js/lib/browser_history.js",
      "lib/cache"           =>  "/app/js/lib/cache.js",
      "lib/calendar"        =>  "/app/js/lib/calendar.js",
      "lib/circuit"         =>  "/app/js/lib/circuit.js",
      "lib/html"            =>  "/app/js/lib/html.js",
      "lib/keyboard"        =>  "/app/js/lib/keyboard.js",
      "lib/loading"         =>  "/app/js/lib/loading.js",
      "lib/modal"           =>  "/app/js/lib/modal.js",
      "lib/piechart"        =>  "/app/js/lib/piechart.js",
      "lib/privilege"       =>  "/app/js/lib/privilege.js",
      "lib/realiteq"        =>  "/app/js/lib/realiteq.js",
      "lib/realiteq_states" =>  "/app/js/lib/realiteq_states.js",
      "lib/state"           =>  "/app/js/lib/state.js",
      "lib/stats"           =>  "/app/js/lib/stats.js",
      "lib/template"        =>  "/app/js/lib/template.js",
      "lib/tooltip"         =>  "/app/js/lib/tooltip.js",
      "lib/tree"            =>  "/app/js/lib/tree.js",
      "lib/ui"              =>  "/app/js/lib/ui.js",
      "lib/utils"           =>  "/app/js/lib/utils.js",
      "lib/weather"         =>  "/app/js/lib/weather.js"
    }
  }

  KEYBOARD_SHORTCUTS = {
    'A'     => 'Show active alerts',
    'C'     => 'Show schema',
    'D'     => 'Set time range to day',
    'H'     => 'Show help',
    'M'     => 'Set time range to month',
    'N, →'  => 'Show next period',
    'P, ←'  => 'Show previous period',
    ','     => 'Show settings'
  }

  Page = -> {
    html5 {
      head {
        meta(charset: 'UTF-8')
        meta(name: 'viewport', content: 'initial-scale = 1.0, user-scalable = no')
        meta(name: 'mobile-web-app-capable', content: 'yes')
        title 'My Dashboard'
        link(href: 'https://unpkg.com/boxicons@2.1.4/css/boxicons.min.css', rel: 'stylesheet')
        link(href: '/app/css/app.css', rel: 'stylesheet')
      }
      body {
        backdrop
        modal
        Header()
        Content()
        Templates()
        import_map(IMPORT_MAP_JSON)
        # script(type: 'importmap') { raw Dashboard::IMPORT_MAP_JSON }
        script_module <<~JS
          import * as ui from "ui";
          await ui.setup();
        JS
      }
    }
  }

  Header = -> {
    header {
      topbar {
        panel_opener {
          input(type: 'checkbox', id: 'secondary-control')
          label(for: 'secondary-control') { hamburger }
        }
        logos {
          img(src: 'https://www.sabresim.co.il/sites/default/files/styles/large/public/800px-Israel_electric_co_0.png?itok=XTzHR597')
          img(src: 'https://main.realiteq.net/resources/ui/topbar-logo')
        }
        heading 'My Dashboard'
        window_view {
          clock '??:??'
          weather '???? ??°C'
        }
        controls {
          span(id: 'btn-alerts', title: 'Show active alerts') {
            i(class: 'bx bx-sm bxs-bell')
            span(class: 'badge')
          }
          span(id: 'btn-settings', title: 'Settings') {
            i(class: 'bx bx-sm bxs-cog')
          }
          span(id: 'btn-help', title: 'Show help') {
            i(class: 'bx bx-sm bxs-help-circle')
          }
        }
      }
    }
  }

  Content = -> {
    content {
      primary {
        ChartContainer()
        footer {
          p {
            text "Powered by "
            a('Acme', href: 'https://acme.com/', target: '_blank')
          }
        }
      }
      secondary {
        BrowserControls()
        schema_container
        browser_container
      }
    }
  }

  ChartContainer = -> {
    chart_container {
      ChartControls()
      ChartHeader()
      chart_container {
        content {
          summary
          legend
          chart
        }
      }
      footer {

      }
    }
  }

  BrowserControls = -> {
    controls {
      tabs {
        input(type: "radio", id: "tab-schema", name: "secondary-tabs", checked: true)
        label(for: "tab-schema") {
          i(class: "bx bx-sm bx-bolt-circle")
          span 'Schema'
        }
        input(type: "radio", id: "tab-browser", name: "secondary-tabs")
        label(for: "tab-browser") {
          i(class: "bx bx-sm bx-search")
          span 'Search'
        }
      }
      group {
        i(class: "bx bx-sm bx-sort-down", title: "Sub circuit order")
        select_with_options(
          id: "sc-sub-circuit-sort", title: "Sub circuit order",
          options: {
            'power'       => 'Power',
            'tagname'     => 'Tagname',
            'description' => 'Description'
          }
        )
      }
    }
  }

  ChartControls = -> {
    controls {
      group {
        select(id: 'cc-preset') {
          options(
            'energy-by-rate'      => 'Energy by rate',
            'cost-by-rate'        => 'Cost by rate',
            'energy-distribution' => 'Energy distribution'
          )
        }
      }
      group {
        select(id: 'cc-period-type') {
          options(
            'day'       => 'Day',
            'week'      => 'Week',
            'month'     => 'Month',
            '3-months'  => '3 months'
          )
        }
      }
      group {
        button(id: 'cc-mode-bar', title: 'Show bar charts') {
          i(class: 'bx bx-sm bx-bar-chart-alt-2')
        }
        button(id: 'cc-mode-table', title: 'Show table') {
          i(class: 'bx bx-sm bx-table')
        }
        button(id: 'cc-mode-pie', title: 'Show pie charts') {
          i(class: 'bx bx-sm bx-pie-chart-alt-2')
        }
      }
    }
  }

  ChartHeader = -> {
    header {
      title {
        circuit_title {
          tagname
          description
        }
        preset_title
      }
      period_controls {
        button(id: 'cc-prev', title: 'Previous time period') {
          i(class: 'bx bx-sm bx-chevrons-left')
        }
        period_title
        button(id: 'cc-next', title: 'Next time period') {
          i(class: 'bx bx-sm bx-chevrons-right')
        }
        button(id: 'cc-now', title: 'Current time period') {
          i(class: 'bx bx-sm bx-last-page')
        }
      }
    }
  }

  Templates = -> {
    template(id: 'template-loading') {
      h2 'Loading...'
    }
    template(id: 'template-help') { TemplateHelp() }
    template(id: "template-alerts-viewer") { TemplateAlertsViewer() }
    template(id: "template-privilege-elevation-form") { TemplatePrivilegeElevation() }
    template(id: "template-search") { TemplateSearch() }
    template(id: "template-schema") { TemplateSchema() }
  }

  TemplateHelp = -> {
    h2 'Keyboard shortcuts'
    table {
      KEYBOARD_SHORTCUTS.each { |key, desc|
        tr {
          td(key, class: 'bold')
          td(desc)
        }
      }
    }
  }

  TemplateAlertsViewer = -> {
    h2 'Active alerts'
    alerts_viewer {
      table {
        tr {
          th 'Circuit'
          th 'Description'
          th 'Start time'
        }
      }
    }
  }

  TemplatePrivilegeElevation = -> {
    privilege_elevation_form {
      form {
        img(src: "/resources/ui/topbar-logo")

        p(id: "instructions")
        div(id: "otp") {
          form_group {
            label('CODE', for: "code")
            input(
              type: "text", name: "code", id: "code", pattern: "[0-9]*",
              inputmode: "numeric", required: true, minlength: "6", maxlength: "6"
            )
          }
        }
        msg_error
        controls {
          button('CANCEL', id: "cancel", type: "button")
          button('CONTINUE', id: "continue", type: "submit", class: "default")
        }
      }
    }
  }

  TemplateSearch = -> {
    search_box {
      topbar {
        input(
          id: "circuit-search", name: "circuit-search", value: "",
          autocomplete: "off", placeholder: "search...", type: "text",
          role: "combobox", spellcheck: "false"
        )
      }
      results
    }
  }

  TemplateSchemaValuesSummary = -> {
    values_summary {
      span {
        span(data_circuitref: "p")
      }
      span {
        text 'PF: '
        span(data_circuitref: "pf")
      }
      span {
        text 'Frequency: '
        span(data_circuitref: "freq")
      }
    }
  }

  TemplateSchemaValuesDetail = -> {
    values_detail {
      span
      span('U',   class:"column-header bold")
      span('I',   class:"column-header bold")
      span('P',   class:"column-header bold")
      span('Q',   class:"column-header bold")
      span('PF',  class:"column-header bold")

      (1..3).each {
        span("L#{it}",  class:"bold")
        span(data_circuitref: "l#{it}-v")
        span(data_circuitref: "l#{it}-c")
        span(data_circuitref: "l#{it}-p")
        span(data_circuitref: "l#{it}-rp")
        span(data_circuitref: "l#{it}-pf")
      }
    }
  }

  TemplateSchema = -> {
    nav {
      breadcrumbs
      auxlinks
    }
    schema {
      current {
        title {
          circuit_tagname
          circuit_description
        }
        related_circuits {
        }
        TemplateSchemaValuesSummary()
        TemplateSchemaValuesDetail()
      }
      sub_circuits
    }
  }
end


html = Dashboard::Page.render
puts html
puts
puts "Size: #{html.bytesize}"
puts
puts Dashboard::Page.compiled_code
puts

Benchmark.ips do |x|
  x.report("page") { Dashboard::Page.render }
  x.report("cached") { Dashboard::Page.render_cached }

  x.compare!(order: :baseline)
end
