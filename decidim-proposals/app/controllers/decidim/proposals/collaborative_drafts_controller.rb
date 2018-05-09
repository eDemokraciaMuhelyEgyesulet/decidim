# frozen_string_literal: true

module Decidim
  module Proposals
    # Exposes Collaborative Drafts resource so users can view and create them.
    class CollaborativeDraftsController < Decidim::Proposals::ApplicationController
      helper Decidim::WidgetUrlsHelper
      helper ProposalWizardHelper
      include FormFactory
      include FilterResource
      include CollaborativeOrderable
      include Paginable

      helper_method :geocoded_collaborative_draft
      before_action :authenticate_user!, only: [:new, :create, :complete]

      def index
        @collaborative_drafts = search
                                .results
                                .includes(:author)
                                .includes(:category)
                                .includes(:scope)

        @collaborative_drafts = paginate(@collaborative_drafts)
        @collaborative_drafts = reorder(@collaborative_drafts)
      end

      def show
        @collaborative_draft = CollaborativeDraft.where(component: current_component).find(params[:id])
        @report_form = form(Decidim::ReportForm).from_params(reason: "spam")
      end

      def new
        enforce_permission_to :create, :collaborative_draft
        @step = :step_1

        @form = form(CollaborativeDraftForm).from_params(
          attachment: form(AttachmentForm).from_params({})
        )
      end

      def compare
        @step = :step_2
        @similar_collaborative_drafts ||= Decidim::Proposals::SimilarCollaborativeDrafts
                                          .for(current_component, params[:collaborative_draft])
                                          .all
        @form = form(CollaborativeDraftForm).from_params(params)

        if @similar_collaborative_drafts.blank?
          flash[:notice] = I18n.t("proposals.collaborative_drafts.compare.no_similars_found", scope: "decidim")
          redirect_to complete_collaborative_drafts_path(collaborative_draft: { title: @form.title, body: @form.body })
        end
      end

      def complete
        enforce_permission_to :create, :collaborative_draft
        @step = :step_3
        if params[:collaborative_draft].present?
          params[:collaborative_draft][:attachment] = form(AttachmentForm).from_params({})
          @form = form(CollaborativeDraftForm).from_params(params)
        else
          @form = form(CollaborativeDraftForm).from_params(
            attachment: form(AttachmentForm).from_params({})
          )
        end
      end

      def create
        enforce_permission_to :create, :collaborative_draft
        @step = :step_3
        @form = form(CollaborativeDraftForm).from_params(params)

        CreateCollaborativeDraft.call(@form, current_user) do
          on(:ok) do |collaborative_draft|
            flash[:notice] = I18n.t("proposals.collaborative_drafts.create.success", scope: "decidim")

            # redirect_to Decidim::ResourceLocatorPresenter.new(collaborative_draft).path
            redirect_to collaborative_draft_path collaborative_draft
          end

          on(:invalid) do
            flash.now[:alert] = I18n.t("proposals.collaborative_drafts.create.error", scope: "decidim")
            render :complete
          end
        end
      end

      def edit
        @collaborative_draft = CollaborativeDraft.where(component: current_component).find(params[:id])
        enforce_permission_to :update, :collaborative_draft, collaborative_draft: @collaborative_draft

        @form = form(CollaborativeDraftForm).from_model(@collaborative_draft)
      end

      def update
        @collaborative_draft = CollaborativeDraft.where(component: current_component).find(params[:id])
        enforce_permission_to :update, :collaborative_draft, collaborative_draft: @collaborative_draft

        @form = form(CollaborativeDraftForm).from_params(params)
        UpdateCollaborativeDraft.call(@form, current_user, @collaborative_draft) do
          on(:ok) do |collaborative_draft|
            flash[:notice] = I18n.t("proposals.collaborative_drafts.update.success", scope: "decidim")
            # redirect_to Decidim::ResourceLocatorPresenter.new(collaborative_draft).path
            redirect_to collaborative_draft_path collaborative_draft
          end

          on(:invalid) do
            flash.now[:alert] = I18n.t("proposals.collaborative_drafts.update.error", scope: "decidim")
            render :edit
          end
        end
      end

      private

      def geocoded_collaborative_draft
        @geocoded_collaborative_draft ||= search.results.not_hidden.select(&:geocoded?)
      end

      def search_klass
        CollaborativeDraftSearch
      end

      def default_filter_params
        {
          search_text: "",
          category_id: "",
          state: "open",
          scope_id: nil,
          related_to: ""
        }
      end
    end
  end
end