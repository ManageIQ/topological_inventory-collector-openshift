module Openshift
  class Parser
    module Template
      def parse_templates(templates)
        templates.each { |template| parse_template(template) }
        collections[:container_templates]
      end

      def parse_template(template)
        container_template = TopologicalInventory::IngressApi::Client::ContainerTemplate.new(
          parse_base_item(template).merge(
            :container_project => lazy_find_namespace(template.metadata&.namespace)
          )
        )

        collections[:container_templates].data << container_template

        container_template
      end

      def parse_template_notice(notice)
        container_template = parse_template(notice.object)
        archive_entity(container_template, notice.object) if notice.type == "DELETED"
      end
    end
  end
end
