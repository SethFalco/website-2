class API::Payments::ActiveSubscriptionsController < API::BaseController
  def show
    render json: AssembleActiveSubscription.(current_user, params.fetch(:product, :donation))
  end
end
