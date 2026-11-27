# Rswag 2.x uses one response MIME type per operation; errors use RFC 9457 instead.
require "yaml"

path = File.expand_path("../swagger/v1/swagger.yaml", __dir__)
document = YAML.safe_load_file(path)

document.fetch("paths").each_value do |path_item|
  path_item.each_value do |operation|
    next unless operation.is_a?(Hash)

    operation.fetch("responses", {}).each do |status, response|
      next unless status.to_i >= 400

      response["content"] = { "application/problem+json" => { "schema" => { "$ref" => "#/components/schemas/problem" } } }
    end
  end
end

File.write(path, YAML.dump(document))
