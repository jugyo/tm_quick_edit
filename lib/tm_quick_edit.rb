module TmQuickEdit
  TM_URL = 'txmt://open?url=file://%s&amp;line=%d&amp;column=%d'

  module ActionView
    def self.included(base)
      base.class_eval do
        def _render_partial_with_tm_quick_edit(options, &block)
          result = _render_partial_without_tm_quick_edit(options, &block)
          template = @renderer.send(:find_template)
          return result unless template.is_a?(::ActionView::Template)

          filelink = TmQuickEdit.tm_quick_edit_link(template.identifier, template.virtual_path)
          filelink.html_safe + result
        end
        alias_method_chain :_render_partial, :tm_quick_edit

        def _render_template_with_tm_quick_edit(template, layout = nil, options = {})
          result = _render_template_without_tm_quick_edit(template, layout, options)
          return result unless template.is_a?(::ActionView::Template)

          filelink = TmQuickEdit.tm_quick_edit_link(template.identifier, template.virtual_path)
          TmQuickEdit.insert_text(result, :after, /<body[^>]*>/i, filelink)
        end
        alias_method_chain :_render_template, :tm_quick_edit
      end
    end
  end

  module ActionController
    def self.included(base)
      base.class_eval do
        after_filter TmQuickEdit::ActionController::Filter
      end
    end

    class Filter
      def self.filter(controller)
        return unless controller.response.content_type == 'text/html'
        controller.response.body = TmQuickEdit.insert_text(controller.response.body, :before, /<\/head>/i, <<-HTML)
          <style type="text/css">
            a.dev-tool-txmt { font-size: 12px; display: none; margin: 0 4px; padding: 2px; color: #C408AF; height: 0; width: 0; }
            #dev-tool { position: fixed; top: 0; right: 0; z-index: 10000; }
            #dev-tool a { font-size: 16px; padding: 2px; text-decoration: none; color: #C408AF; }
          </style>
        HTML

        filelink = TmQuickEdit.tm_quick_edit_link(
          Rails.root.join("app/controllers/#{controller.controller_path}_controller.rb"), "#{controller.controller_path}_controller")
        controller.response.body = TmQuickEdit.insert_text(controller.response.body, :after, /<body[^>]*>/i, filelink)

        controller.response.body = TmQuickEdit.insert_text(controller.response.body, :before, /<\/body>/i, <<-HTML)
          <div id="dev-tool">
            <a href="javascript:void(0);" onclick="$('.dev-tool-txmt').toggle()" title="tm_quick_edit">&#10037;</a>
          </div>
        HTML
      end
    end
  end

  def self.tm_quick_edit_link(filepath, title)
    fileurl = TM_URL % [filepath, 0, 0]
    '<a href="%s" class="dev-tool-txmt" title="%s"><span style="display: inline-block">&#9998; %s</span></a>' % [fileurl, title, title]
  end

  def self.insert_text(content, position, pattern, new_text)
    index = if match = content.match(pattern)
      match.offset(0)[position == :before ? 0 : 1]
    else
      content.size
    end
    content.insert index, new_text
  end
end

ActionView::Base.__send__(:include, TmQuickEdit::ActionView)
ActionController::Base.__send__(:include, TmQuickEdit::ActionController)
