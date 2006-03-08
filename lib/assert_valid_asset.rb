require 'test/unit'
require 'net/http'
require 'digest/md5'
require 'ftools'

class Test::Unit::TestCase

  # Assert that markup (html/xhtml) is valid according the W3C validator web service.
  # By default, it validates the contents of @response.body, which is set after calling
  # one of the get/post/etc helper methods. You can also pass it a string to be validated.
  # Validation errors, if any, will be included in the output. The input fragment and 
  # response from the validator service will be cached in the $RAILS_ROOT/tmp directory to 
  # minimize network calls.
  #
  # For example, if you have a FooController with an action Bar, put this in foo_controller_test.rb:
  #
  #   def test_bar_valid_markup
  #     get :bar
  #     assert_valid_markup
  #   end
  #
  def assert_valid_markup(fragment=@response.body)
    base_filename = cache_resource('markup',fragment,'html')

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

  # Class-level method to quickly create validation tests for a bunch of actions at once.
  # For example, if you have a FooController with three actions, just add one line to foo_controller_test.rb:
  #
  #   assert_valid_markup :bar, :baz, :qux
  #
  # If you pass :but_first => :something, #something will be called at the beginning of each test case
  def self.assert_valid_markup(*actions)
    options = actions.find { |i| i.kind_of? Hash }
    actions.delete_if { |i| i.kind_of? Hash }
    actions.each do |action|
      toeval = "def test_#{action}_valid_markup\n"
      toeval << "#{options[:but_first].id2name}\n" if options and options[:but_first]
      toeval << "get :#{action}\n"
      toeval << "assert_valid_markup\n"
      toeval << "end\n"
      class_eval toeval
    end
  end

  # Assert that css is valid according the W3C validator web service.
  # You pass the css as a string to the method. Validation errors, if any, 
  # will be included in the output. The input fragment and response from 
  # the validator service will be cached in the $RAILS_ROOT/tmp directory to 
  # minimize network calls.
  #
  # For example, if you have a css file standard.css you can add the following test;
  #
  #   def test_standard_css
  #     assert_valid_css(File.open("#{RAILS_ROOT}/public/stylesheets/standard.css",'rb').read)
  #   end
  #
  def assert_valid_css(css)
    base_filename = cache_resource('css',css,'css')
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

  # Class-level method to quickly create validation tests for a bunch of css files relative to 
  # $RAILS_ROOT/public/stylesheets and ending in '.css'.
  #
  # The following example validates layout.css and standard.css in the standard directory ($RAILS_ROOT/public/stylesheets);
  #
  #   class CssTest < Test::Unit::TestCase
  #     assert_valid_css 'layout', 'standard'
  #   end
  #
  def self.assert_valid_css(*files)
    files.each do |file|
      filename = "#{RAILS_ROOT}/public/stylesheets/#{file}.css"
      toeval = "def test_#{file.gsub(/-/,'_')}_valid_css\n"
      toeval << "  assert_valid_css(File.open('#{filename}','rb').read)\n"
      toeval << "end\n"
      class_eval toeval
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

  def cache_resource(base,resource,extension)
    resource_md5 = MD5.md5(resource).to_s
    file_md5 = nil

    output_dir = "#{RAILS_ROOT}/tmp/#{base}"
    base_filename = File.join(output_dir, self.class.name.gsub(/\:\:/,'/').gsub(/Controllers\//,'') + '.' + method_name + '.')
    filename = base_filename + extension
    
    parent_dir = File.dirname(filename) 
    File.makedirs(parent_dir) unless File.exists?(parent_dir)

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
