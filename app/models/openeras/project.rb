# encoding: utf-8

module Openeras
  class Project < ActiveRecord::Base

    acts_as_iox_document

    attr_accessor :venue_id, :locale, :init_label_id, :label_ids

    belongs_to  :creator, class_name: 'Iox::User', foreign_key: 'created_by'
    belongs_to  :updater, class_name: 'Iox::User', foreign_key: 'updated_by'
    has_many    :events, -> { order(:starts_at) }, class_name: 'Openeras::Event', dependent: :destroy
    has_many    :images, -> { order(:position) }, class_name: 'Openeras::File', dependent: :destroy

    has_many    :labeled_items, dependent: :destroy
    has_many    :labels, through: :labeled_items

    has_many    :venues, through: :events

    has_many    :project_people, dependent: :destroy
    has_many    :people, through: :project_people

    has_many    :files, as: :fileable, dependent: :destroy

    validates   :title, presence: true, length: { in: 2..255 }
    validates   :subtitle, length: { maximum: 255 }
    validates   :age, inclusion: { in: 1..20 }, numericality: true, allow_blank: true
    validates   :duration, inclusion: { in: 1..960 }, numericality: true, allow_blank: true

    has_many    :translations, as: :localeable, dependent: :delete_all, class_name: 'Iox::Translation'

    accepts_nested_attributes_for :translations

    def venue_name
      names = []
      if events && events.size > 0 
        events.each do |event|
          names << event.venue.name if event.venue && !names.include?(event.venue.name)
        end
      end
      names.join(',')
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

    def as_json(options = { })
      h = super(options)
      h[:venue_id] = venue_id
      h[:venue_name] = venue_name
      h[:translation] = translation
      h[:translations] = translations
      h[:locale] = locale || I18n.locale
      h[:labels] = new_record? ? [] : labels
      h[:files] = new_record? ? [] : files
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