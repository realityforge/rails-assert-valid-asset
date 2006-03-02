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
    base_filename = cache_resource(fragment,'html')

    return unless base_filename
    results_filename =  base_filename + '-results.yml'

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

  # Assert that css is valid according the W3C validator web service.
  def assert_valid_css(css)
    base_filename = cache_resource(css,'css')
    results_filename =  base_filename + 'results.yml'
    begin
      response = File.open(results_filename) do |f| Marshal.load(f) end
    rescue
      params = [ 
        file_to_multipart('file','file.css','text/css',css),
        text_to_multipart('warning','1'),
        text_to_multipart('profile','css2'),
        text_to_multipart('usermedium','all') ]
      
      boundary = '-----------------------------24464570528145'
      query = params.collect { |p| '--' + boundary + "\r\n" + p }.join('') + boundary + "--\r\n"

      response = http.start('jigsaw.w3.org').post2("/css-validator/validator",query,"Content-type" => "multipart/form-data; boundary=" + boundary)
      File.open(results_filename, 'w+') do |f| Marshal.dump(response, f) end
    end
    messages = []
    REXML::XPath.each( REXML::Document.new(response.body).root, "//div[@id='errors']/div/ul/li") do |element|
      messages << element.to_s.gsub(/<[^>]+>/,' ').gsub(/\n/,' ').gsub(/\s+/, ' ')
    end
    if messages.length > 0
      message = messages.join("\n")
      flunk("CSS Validation failed:\n#{message}")
    end
  end

private
  def text_to_multipart(key,value)
    return "Content-Disposition: form-data; name=\"#{CGI::escape(key)}\"\r\n\r\n#{value}\r\n"
  end

  def file_to_multipart(key,filename,mime_type,content)
    return "Content-Disposition: form-data; name=\"#{CGI::escape(key)}\"; filename=\"#{filename}\"\r\n" +
              "Content-Transfer-Encoding: binary\r\nContent-Type: #{mime_type}\r\n\r\n#{content}\r\n"
  end

  def cache_resource(resource,extension)
    resource_md5 = MD5.md5(resource).to_s
    file_md5 = nil

    output_dir = "#{RAILS_ROOT}/temp"
    base_filename = File.join(output_dir, self.class.name.gsub(/\:\:/,'/').gsub(/Controllers\//,'') + '.' + method_name + '.')
    filename = base_filename + extension
    
    parent_dir = File.dirname(filename) 
    Dir.mkdir(parent_dir) unless File.exists?(parent_dir)

    File.open(filename, 'r') do |f| 
      file_md5 = MD5.md5(f.read(f.stat.size)).to_s
    end if File.exists?(filename)

    if file_md5 != resource_md5
      Dir["#{base_filename}[^.]*"] .each {|f| File.delete(f)}
      File.open(filename, 'w+') do |f| f.write(resource); end
    end  
    base_filename
  end

  def http
    if Module.constants.include?("ApplicationConfig") && ApplicationConfig.respond_to?(:proxy_config)
      Net::HTTP::Proxy(ApplicationConfig.proxy_config['host'], ApplicationConfig.proxy_config['port'])
    else
      Net::HTTP
    end
  end
end
