# encoding: utf-8

module Openeras
  class Project < ActiveRecord::Base

    acts_as_iox_document

    attr_accessor :venue_id, :locale, :init_label_id, :label_ids

    belongs_to  :creator, class_name: 'Iox::User', foreign_key: 'created_by'
    belongs_to  :updater, class_name: 'Iox::User', foreign_key: 'updated_by'
    has_many    :events, -> { order(:starts_at) }, class_name: 'Openeras::Event', dependent: :destroy

    has_many    :labeled_items, dependent: :destroy
    has_many    :labels, through: :labeled_items

    has_many    :venues, through: :events

    has_many    :project_people, -> { order(:position) }, dependent: :destroy
    has_many    :people, through: :project_people

    has_many    :files, -> { order(:position) }, as: :fileable, dependent: :destroy
    has_many    :images, -> { where("file_content_type LIKE 'image%'").order(:position) }, class_name: 'Openeras::File', as: :fileable, dependent: :destroy

    validates   :title, presence: true, length: { in: 2..255 }
    validates   :subtitle, length: { maximum: 255 }
    validates   :age, inclusion: { in: 1..20 }, numericality: true, allow_blank: true
    validates   :duration, inclusion: { in: 1..960 }, numericality: true, allow_blank: true

    has_many    :translations, as: :localeable, dependent: :delete_all, class_name: 'Iox::Translation'

    accepts_nested_attributes_for :translations

    def venue_name
      unique_venues.map{ |v| v.name }.join(',')
    end

    def unique_venues
      vens = []
      venids = []
      venues.each do |ven|
        next if venids.include?(ven.id)
        venids << ven.id
        vens << ven
      end
      vens
    end

    def translation
      return @translation if @translation
      @translation = translations.where( locale: (locale || I18n.locale) ).first
      @translation = translations.where( locale: I18n.locale ).first unless @translation
      if !@translation 
        if new_record?
          @translation = translations.build( locale: (locale || I18n.locale), title: title ) 
        else
          @translation = translations.create!( locale: (locale || I18n.locale), title: title ) 
        end
      end
      @translation
    end

    def to_param
      [id, title.parameterize].join("-")
    end

    def get_youtube_url
      return '' if youtube_url.blank?
      return youtube_url if youtube_url.split('=').size < 2
      youtube_id = youtube_url.split('=')[1]
      "//www.youtube.com/embed/#{youtube_id}"
    end

    def get_vimeo_url
      return '' if vimeo_url.blank?
      return vimeo_url if vimeo_url.split('vimeo.com/').size < 2
      vimeo_id = vimeo_url.split('vimeo.com/')[1]
      "//player.vimeo.com/video/#{vimeo_id}"
    end

    def as_json(options = { })
      h = super(options)
      h[:venue_id] = venue_id
      h[:venue_name] = venue_name
      h[:translation] = translation
      h[:translations] = translations
      h[:events] = events
      h[:locale] = locale || I18n.locale
      h[:labels] = new_record? ? [] : labels
      h[:files] = new_record? ? [] : files
      h[:image_thumb_url] = files.size > 0 ? images.first.file.url(:thumb) : nil
      h[:to_param] = to_param unless new_record?
      h[:available_locales] = Rails.configuration.iox.available_langs || [:en]
      h[:updater_name] = updater ? updater.full_name : ( creator ? creator.full_name : '' )
      h
    end

    def update_label_ids
      return if ( ( label_ids.nil? || label_ids.size < 1 ) && labeled_items.size < 1 )
      labeled_items.delete_all
      return unless label_ids.is_a?(Array)
      label_ids.each do |label_id|
        labeled_items.create label_id: label_id, project_id: id
      end
    end

  end
end
