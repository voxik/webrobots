require 'helper'

class TestWebRobots < Test::Unit::TestCase
  context "robots.txt with no rules" do
    setup do
      @robots = WebRobots.new('RandomBot', :http_get => lambda { |uri|
          case uri.to_s
          when 'http://site1.example.org/robots.txt'
            <<-'TXT'
            TXT
          when 'http://site2.example.org/robots.txt'
            <<-'TXT'

  
            TXT
          when 'http://site3.example.org/robots.txt'
            <<-'TXT'

  #comment
            TXT
          when 'http://site4.example.org/robots.txt'
            <<-'TXT'

  #comment
	
            TXT
          when 'http://site5.example.org/robots.txt'
            raise Net::HTTPNotFound
          else
            raise "#{uri} is not supposed to be fetched"
          end
        })
    end

    should "allow any robot" do
      assert @robots.allowed?('http://site1.example.org/index.html')
      assert @robots.allowed?('http://site1.example.org/private/secret.txt')
      assert @robots.allowed?('http://site2.example.org/index.html')
      assert @robots.allowed?('http://site2.example.org/private/secret.txt')
      assert @robots.allowed?('http://site3.example.org/index.html')
      assert @robots.allowed?('http://site3.example.org/private/secret.txt')
      assert @robots.allowed?('http://site4.example.org/index.html')
      assert @robots.allowed?('http://site4.example.org/private/secret.txt')
    end
  end

  context "robots.txt with some rules" do
    setup do
      http_get = lambda { |uri|
        case uri.to_s
        when 'http://www.example.org/robots.txt'
          <<-'TXT'
# Punish evil bots
User-Agent: evil
Disallow: /

User-Agent: good
# Be generous to good bots
Disallow: /2heavy/
Allow: /2heavy/*.htm
Disallow: /2heavy/*.htm$

User-Agent: *
Disallow: /2heavy/
Disallow: /index.html
# Allow takes precedence over Disallow if the pattern lengths are the same.
Allow: /index.html
          TXT
        when 'http://www.example.com/robots.txt'
          <<-'TXT'
# Default rule is evaluated last even if it is put first.
User-Agent: *
Disallow: /2heavy/
Disallow: /index.html
# Allow takes precedence over Disallow if the pattern lengths are the same.
Allow: /index.html

# Punish evil bots
User-Agent: evil
Disallow: /

User-Agent: good
# Be generous to good bots
Disallow: /2heavy/
Allow: /2heavy/*.htm
Disallow: /2heavy/*.htm$
          TXT
        else
          raise "#{uri} is not supposed to be fetched"
        end
      }

      @robots = WebRobots.new('RandomBot', :http_get => http_get)
      @robots_good = WebRobots.new('GoodBot', :http_get => http_get)
      @robots_evil = WebRobots.new('EvilBot', :http_get => http_get)
    end

    should "properly restrict access" do
      assert  @robots_good.allowed?('http://www.example.org/index.html')
      assert !@robots_good.allowed?('http://www.example.org/2heavy/index.php')
      assert  @robots_good.allowed?('http://www.example.org/2heavy/index.html')
      assert !@robots_good.allowed?('http://www.example.org/2heavy/index.htm')

      assert !@robots_evil.allowed?('http://www.example.org/index.html')
      assert !@robots_evil.allowed?('http://www.example.org/2heavy/index.php')
      assert !@robots_evil.allowed?('http://www.example.org/2heavy/index.html')
      assert !@robots_evil.allowed?('http://www.example.org/2heavy/index.htm')

      assert  @robots.allowed?('http://www.example.org/index.html')
      assert !@robots.allowed?('http://www.example.org/2heavy/index.php')
      assert !@robots.allowed?('http://www.example.org/2heavy/index.html')
      assert !@robots.allowed?('http://www.example.org/2heavy/index.htm')

      assert  @robots_good.allowed?('http://www.example.com/index.html')
      assert !@robots_good.allowed?('http://www.example.com/2heavy/index.php')
      assert  @robots_good.allowed?('http://www.example.com/2heavy/index.html')
      assert !@robots_good.allowed?('http://www.example.com/2heavy/index.htm')

      assert !@robots_evil.allowed?('http://www.example.com/index.html')
      assert !@robots_evil.allowed?('http://www.example.com/2heavy/index.php')
      assert !@robots_evil.allowed?('http://www.example.com/2heavy/index.html')
      assert !@robots_evil.allowed?('http://www.example.com/2heavy/index.htm')

      assert  @robots.allowed?('http://www.example.com/index.html')
      assert !@robots.allowed?('http://www.example.com/2heavy/index.php')
      assert !@robots.allowed?('http://www.example.com/2heavy/index.html')
      assert !@robots.allowed?('http://www.example.com/2heavy/index.htm')
    end
  end

  context "robots.txt with errors" do
    setup do
      @http_get = lambda { |uri|
        case uri.to_s
        when 'http://www.example.org/robots.txt'
          <<-'TXT'
# some comment
User-Agent: first
# Disallow: /
Disallow: /2heavy/
# Allow: /2heavy/notsoheavy
Allow: /2heavy/*.html
#
User-Agent: next
# Disallow: /
Disallow: /2heavy/
# Allow: /2heavy/notsoheavy
Allow: /2heavy/*.html
          TXT
        when 'http://www.example.com/robots.txt'
          <<-'TXT'
# some comment
#User-Agent: first
# Disallow: /
Disallow: /2heavy/
# Allow: /2heavy/notsoheavy
Allow: /2heavy/*.html

User-Agent: next
# Disallow: /
Disallow: /2heavy/
# Allow: /2heavy/notsoheavy
Allow: /2heavy/*.html
          TXT
        else
          raise "#{uri} is not supposed to be fetched"
        end
      }
    end

    should "raise ParseError" do
      robots = WebRobots.new('RandomBot', :http_get => @http_get)
      assert_raise(WebRobots::ParseError) {
        robots.allowed?('http://www.example.org/2heavy/index.html')
      }
      assert_raise(WebRobots::ParseError) {
        robots.allowed?('http://www.example.com/2heavy/index.html')
      }
    end
  end

  context "robots.txt with options" do
    setup do
      http_get = lambda { |uri|
        case uri.to_s
        when 'http://www.example.org/robots.txt'
          <<-'TXT'
Sitemap: http://www.example.org/sitemap-host1.xml
Sitemap: http://www.example.org/sitemap-host2.xml

User-Agent: MyBot
Disallow: /2heavy/
Allow: /2heavy/*.html
Option1: Foo
Option2: Hello

User-Agent: *
Disallow: /2heavy/
Allow: /2heavy/*.html
Option1: Bar
Option3: Hi
          TXT
        else
          raise "#{uri} is not supposed to be fetched"
        end
      }

      @robots_mybot = WebRobots.new('MyBot', :http_get => http_get)
      @robots_hisbot = WebRobots.new('HisBot', :http_get => http_get)
    end

    should "read options" do
      options = @robots_mybot.options('http://www.example.org/')
      assert_equal 2, options.size
      assert_equal 'Foo',   @robots_mybot.option('http://www.example.org/', 'Option1')
      assert_equal 'Foo',   options['option1']
      assert_equal 'Hello', @robots_mybot.option('http://www.example.org/', 'Option2')
      assert_equal 'Hello', options['option2']

      options = @robots_hisbot.options('http://www.example.org/')
      assert_equal 2, options.size
      assert_equal 'Bar',   @robots_hisbot.option('http://www.example.org/', 'Option1')
      assert_equal 'Bar',   options['option1']
      assert_equal 'Hi',    @robots_hisbot.option('http://www.example.org/', 'Option3')
      assert_equal 'Hi',    options['option3']

      assert_equal %w[
        http://www.example.org/sitemap-host1.xml
        http://www.example.org/sitemap-host2.xml
      ], @robots_mybot.sitemaps('http://www.example.org/')
      assert_equal %w[
        http://www.example.org/sitemap-host1.xml
        http://www.example.org/sitemap-host2.xml
      ], @robots_hisbot.sitemaps('http://www.example.org/')
    end
  end

  context "robots.txt with options" do
    setup do
      http_get = lambda { |uri|
        case uri.to_s
        when 'http://www.example.org/robots.txt'
          <<-'TXT'
User-Agent: *
Disallow: /
          TXT
        else
          raise "#{uri} is not supposed to be fetched"
        end
      }

      @robots = WebRobots.new('RandomBot', :http_get => http_get)
    end

    should "validate URI" do
      assert_raise(ArgumentError) {
        @robots.allowed?('www.example.org/')
      }
      assert_raise(ArgumentError) {
        @robots.allowed?('::/home/knu')
      }
    end
  end

  context "robots.txt in the real world" do
    setup do
      @testbot = WebRobots.new('TestBot')
      @msnbot = WebRobots.new('TestMSNBot')	# matches msnbot
    end

    should "be parsed for major sites" do
      assert_nothing_raised {
        assert !@testbot.allowed?("http://www.google.com/search")
        assert !@testbot.allowed?("http://www.google.com/news/section?pz=1&cf=all&ned=jp&topic=y&ict=ln")
        assert @testbot.allowed?("http://www.google.com/news/directory?pz=1&cf=all&ned=us&hl=en&sort=users&category=6")
      }
      assert_nothing_raised {
        assert @testbot.allowed?("http://www.yahoo.com/")
        assert !@testbot.allowed?("http://www.yahoo.com/?")
        assert !@testbot.allowed?("http://www.yahoo.com/p/foo")
      }
      assert_nothing_raised {
        assert !@testbot.allowed?("http://store.apple.com/vieworder")
        assert @msnbot.allowed?("http://store.apple.com/vieworder")
      }
#      assert_nothing_raised {
        assert !@testbot.allowed?("http://github.com/login")
#      }
    end
  end
end