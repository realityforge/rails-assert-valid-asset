require 'test/unit'
require 'net/http'
require 'digest/md5'

class Test::Unit::TestCase

  # Assert that markup (html/xhtml) is valid according the W3C validator web service.
  # By default, it validates the contents of @response.body, which is set after calling
  # one of the get/post/etc helper methods. You can also pass it a string to be validated.
  # Validation errors, if any, will be included in the output. The response from the validator
  # service will be cached in the system temp directory to minimize duplicate calls.
  #
  # For example, if you have a FooController with an action Bar, put this in foo_controller_test.rb:
  #
  #   def test_bar_valid_markup
  #     get :bar
  #     assert_valid_markup
  #   end
  #
  def assert_valid_markup(fragment=@response.body)
    fragment_md5 = MD5.md5(fragment).to_s
    file_md5 = nil

    output_dir = "#{RAILS_ROOT}/temp"
    base_filename = File.join(output_dir, self.class.name.gsub(/\:\:/,'/').gsub(/Controllers\//,'') + '.' + method_name)

    parent_dir = File.dirname(base_filename) 
    Dir.mkdir(parent_dir) unless File.exists?(parent_dir)

    content_filename = base_filename + '.html'

    File.open(content_filename, 'r') do |f| 
      file_md5 = MD5.md5(f.read(f.stat.size)).to_s
    end if File.exists?(content_filename)

    results_filename =  base_filename + '-results.yml'

    if file_md5 != fragment_md5
      File.open(content_filename, 'w+') do |f| f.write(fragment); end
      File.delete(results_filename) if File.exists?(results_filename)
    end

    begin
      response = File.open(results_filename) do |f| Marshal.load(f) end
    rescue
      response = http.start('validator.w3.org').post2('/check', "fragment=#{CGI.escape(fragment)}&output=xml")
      File.open(results_filename, 'w+') do |f| Marshal.dump(response, f) end
    end
    markup_is_valid = response['x-w3c-validator-status'] == 'Valid'
    message = markup_is_valid ? '' :  XmlSimple.xml_in(response.body)['messages'][0]['msg'].collect{ |m| "Invalid markup: line #{m['line']}: #{CGI.unescapeHTML(m['content'])}" }.join("\n")
    assert(markup_is_valid, message)
  end

private
  def http
    if ApplicationConfig && ApplicationConfig.respond_to?(:proxy_config)
      Net::HTTP::Proxy(ApplicationConfig.proxy_config['host'], ApplicationConfig.proxy_config['port'])
    else
      Net::HTTP
    end
  end
end
