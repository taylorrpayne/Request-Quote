require 'test_helper'

class OrdersControllerTest < ActionDispatch::IntegrationTest
  test "should get create_draft_order" do
    get orders_create_draft_order_url
    assert_response :success
  end

end
