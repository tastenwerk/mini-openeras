module Openeras
  class PricesController < Iox::ApplicationController

    before_filter :authenticate!

    def index
      @event = Event.find_by_id( params[:event_id] )
      @prices = @event.prices
      if params[:query] && !params[:query].blank?
        @prices.where("name LIKE ?", "%#{params[:query]}")
      end
      @total = @prices.count

      @order = 'price asc'
      if params[:sort]
        sort = params[:sort]['0'][:field]
        unless sort.blank?
          @order = "#{sort} #{params[:sort]['0'][:dir]}"
        end
      end
      @prices = @prices.order( @order )

      render json: { items: @prices.load, total: @total, order: @order }
    end

    def create
      @event = Event.find_by_id( params[:event_id] )
      @price = @event.prices.build price_params
      if @price.save
        @event.event_prices.create!( price_id: @price.id ) unless @event.event_prices.where( price_id: @price.id ).first
        flash.now.notice = t('openeras.price.saved')
      else
        flash.now.alert = t('openeras.price.saving_failed')
      end
      render json: { flash: flash, success: flash[:alert].blank?, item: @price }
    end

    def update
      @price = Price.find_by_id( params[:id] )
      if @price.update price_params
        flash.now.notice = t('openeras.price.saved')
      else
        flash.now.alert = t('openeras.price.saving_failed')
      end
      render json: { flash: flash, success: flash[:alert].blank?, item: @price }
    end

    def apply_project
      @event = Event.find_by_id( params[:event_id] )
      @event.project.events.each do |event|
        next if event.id == @event.id
        event.event_prices.delete_all
        @event.prices.each do |price|
          event.event_prices.create!( price_id: price.id ) unless event.event_prices.where( price_id: price.id ).first
        end
      end
      flash.now.notice = t('openeras.price.project_updated', name: @event.project.title)
      render json: { flash: flash, success: flash[:alert].blank? }
    end

    def apply_systemwide
      @event = Event.find_by_id( params[:event_id] )
      Event.where("starts_at >= ?", Time.now).each do |event|
        next if event.id == @event.id
        event.prices.map(&:destroy)
        @event.prices.each do |price|
          event.event_prices.create!( price_id: price.id ) unless event.event_prices.where( price_id: price.id ).first
        end
      end
      flash.now.notice = t('openeras.price.systemwide_updated', name: @event.project.title)
      render json: { flash: flash, success: flash[:alert].blank? }
    end

    def make_template
      @event = Event.find_by_id( params[:event_id] )
      oldprices = Price.where(template: true).each{ |p| p.update template: false }
      @event.prices.each do |price|
        price.update template: true
      end
      flash.now.notice = t('openeras.price.made_template')
      render json: { flash: flash, success: flash[:alert].blank? }
    end

    def destroy
      @price = Price.find_by_id( params[:id] )
      if @price.destroy
        flash.now.notice = t('openeras.price.deleted')
      else
        flash.now.alert = t('openeras.price.deletion_failed')
      end
      render json: { flash: flash, success: flash[:alert].blank?, item: @price }
    end

    private

    def price_params
      params.require(:price).permit( :name, :note, :price, :id )
    end

  end
end
