= assert_valid_asset plugin for Rails

assert_valid_asset is a plugin to validate your (X)HTML and CSS using the W3C Validator 
web service (http://validator.w3.org/) and the W3C CSS Validation Service 
(http://jigsaw.w3.org/css-validator) as part of your functional or unit tests. 
The css and html fragments are cached in $RAILS_ROOT/tmp/test/assets as are the results 
from the web service. This means that your tests will not be slowed down unless the output 
has changed.

The code started life as a few modifications to Scott Raymond's assert_valid_markup
(http://redgreenblu.com/svn/projects/assert_valid_markup/) and evolved to cache fragments
and results in $RAILS_ROOT/tmp/test/assets rather than the system temp directory. Then the 
ability to validate CSS files was added. I also added the ability to skip checks if the 
"NONET" environment variable is set to "true". 

Most of the credit goes to Scott for his initial idea!

== HowTo Validate (X)HTML

  # Calling the assertion with no parameters validates whatever is in @request.body,
  # which is automatically set by the existing get/post/etc helpers. For example:

    class FooControllerTest < Test::Unit::TestCase
      def test_bar_markup
        get :bar
        assert_valid_markup
      end
    end

  # Add a string parameter to the assertion to validate any random fragment. For example:

    class FooControllerTest < Test::Unit::TestCase
      def test_bar_markup
        assert_valid_markup "<div>Hello, world.</div>"
      end
    end

  # For the ultimate in convenience, use the class-level method to validate a slew of
  # actions in one line. Par exemple:

    class FooControllerTest < Test::Unit::TestCase
      assert_valid_markup :bar, :baz, :qux
    end

== HowTo Validate CSS

  # Pass a string parameter to the assertion to validate a css fragment. For example:

    class FooControllerTest < Test::Unit::TestCase
      def test_bar_css
        assert_valid_css(File.open("#{RAILS_ROOT}/public/stylesheets/bar.css",'rb').read)
      end
    end

  # For the ultimate in convenience, use the class-level method to validate a slew of
  # css files in one line. Assumes that the CSS files are relative to 
  # $RAILS_ROOT/public/stylesheets/ and end with '.css'. The following example validates 
  # $RAILS_ROOT/public/stylesheets/layout.css, $RAILS_ROOT/public/stylesheets/standard.css
  # and $RAILS_ROOT/public/stylesheets/theme.css

    class FooControllerTest < Test::Unit::TestCase
      assert_valid_css_files 'layout', 'standard', 'theme'
    end

== Details

License: Released under the MIT license.
Latest Version: http://www.realityforge.org/svn/public/code/assert-valid-asset/trunk/

== Credits

Scott Raymond <sco@scottraymond.net> for the initial version. 
Peter Donald <peter at realityforge dot org> to add validation of CSS files and fix caching.

