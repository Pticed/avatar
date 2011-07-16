require 'avatar/object_support'
require 'avatar/source/abstract_source'
require 'avatar/source/static_url_source'
require 'avatar/source/nil_source'
require 'digest/md5'

module Avatar # :nodoc:
  module Source # :nodoc:
    # NOTE: since Gravatar always returns a URL (never a 404), instances of this
    # class should only be placed at the end of a SourceChain.
    # (see link:classes/Avatar/Source/SourceChain.html)
    # Alternatively, use <code>default_source = ...</code> to generate a site-wide
    # default to be passed to Gravatar.  (In fact, since <code>default_source</code>
    # is an instance of Avatar::Source::AbstractSource, it can generate a different
    # default for each person.)
    class GravatarSource
      include AbstractSource
      
      attr_accessor :default_field
      attr_reader :default_source
      
      # 'http://www.gravatar.com/avatar/'
      def self.base_url
        'http://www.gravatar.com/avatar/'
      end
      
      # ['G', 'PG', 'R', 'X', 'any']
      def self.allowed_ratings
        ['G', 'PG', 'R', 'X', 'any']
      end
      
      # Arguments:
      # * +default_source+: a Source to generate defaults to be passed to Gravatar; optional; default: nil (a NilSource).
      # * +default_field+: the field within each +person+ passed to <code>avatar_url_for</code> in which to look for an email address
      def initialize(default_source = nil, default_field = :email)
        self.default_source = default_source #not @default_source = ... b/c want to use the setter function below
        @default_field = default_field
        raise "There's a bug in the code" if @default_source.nil?
      end
      
      # Generates a Gravatar URL.  Returns nil if person is nil.
      # Options: 
      # * <code>:gravatar_field (Symbol)</code> - the field to call from person.  By default, <code>:email</code>.
      # * <code>:gravatar_default_url (String)</code> - override the default generated by <code>default_source</code>.
      # * <code>:gravatar_size or size or :s</code> - the size in pixels of the avatar to render.
      # * <code>:gravatar_rating or rating or :r</code> - the maximum rating; one of ['G', 'PG', 'R', 'X']
      def avatar_url_for(person, options = {})
        return nil if person.nil?
        options = parse_options(person, options)
        field = options.delete(:gravatar_field)
        raise ArgumentError.new('No field specified; either specify a default field or pass in a value for :gravatar_field (probably :email)') unless field
        
        email = person.send(field)
        return nil if email.nil? || email.to_s.blank?
        email = email.to_s.downcase
        
        returning(self.class.base_url) do |url|
          url << Digest::MD5::hexdigest(email).strip
          # default must be last or the other options will be parameters to that URL, not the Gravatar one
          [:size, :rating, :default].each do |k|
            v = options[k]
            next if v.nil?
            url << (url.include?('?') ? '&' : '?')
            url << "#{k}=#{v}"
          end
        end
      end
      
      # Returns a Hash containing
      # * :field - value of :gravatar_field; defaults to <code>self.default_field</code>
      # * :default - value of :gravatar_default_url; defaults to <code>self.default_avatar_url_for(+person+, +options+)</code>
      # * :size - value of :gravatar_size or :size or :s passed through <em>only if a number</em>
      # * :rating - value of :gravatar_rating or :rating or :r passed through <em>only if one of <code>self.class.allowed_ratings</code></em>
      def parse_options(person, options)
        returning({}) do |result|
          result[:gravatar_field] = options[:gravatar_field] || default_field
          
          default = options[:gravatar_default_url] || default_avatar_url_for(person, options) || options[:d] || options[:default]
          raise "default must be a fully-qualified URL with port and host or a default avatar type" unless (self.class.valid_default_url?(default) || self.class.valid_default_value?(default))
          result[:default] = default

          size = (options[:gravatar_size] || options[:size] || options[:s] || '').to_s.to_i
          result[:size] = size if size > 0

          rating = options[:gravatar_rating] || options[:rating] || options[:r]
          result[:rating] = rating if rating and self.class.allowed_ratings.include?(rating.to_s)
        end
      end
      
      # Set the default source for all people.
      # If +default+ is a String, it will be converted to an instance of Avatar::Source::StaticUrlSource.
      # If +default+ is nil, sets the default to a NilSource.
      def default_source=(default)
        case default
        when String
          @default_source = StaticUrlSource.new(default)
        when AbstractSource
          @default_source = default
        when NilClass
          @default_source = NilSource.new
        else
          raise ArgumentError.new("#{default} must be either a String or an instance of #{AbstractSource}")
        end
      end

      def self.valid_default_url?(url)
        url.nil? || url =~ /^http[s]?\:/
      end

      def self.valid_default_value?(value)
        ["404", "mm", "identicon", "monsterid", "wavatar", "retro"].include?(value)
      end
      
      private
      
      def default_avatar_url_for(person, options)
        @default_source.avatar_url_for(person, options)
      end
      
    end
  end
end