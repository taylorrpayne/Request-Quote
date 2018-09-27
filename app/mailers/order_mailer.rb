class OrderMailer < ApplicationMailer
	def customer_mail(subject,to,first_name)
		@first_name = first_name
		mail from: "bill@miataroadster.com <john.martine1234@gmail.com>", to: to,reply_to: "bill@miataroadster.com", subject: subject
	end

	def admin_mail(subject,to,draft_order,store_name,currency_symbol)
		@draft_order = draft_order
		@store_name = store_name
		@currency_symbol = currency_symbol
		mail from: "bill@miataroadster.com <john.martine1234@gmail.com>", to: to,reply_to: "bill@miataroadster.com", subject: subject
	end
end
