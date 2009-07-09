module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class Protx3dsGateway < ProtxGateway
     
      # need update in parent 
      TEST_URL = 'https://test.sagepay.com/gateway/service'
      LIVE_URL = 'https://live.sagepay.com/gateway/service'
      SIMULATOR_URL = 'https://test.sagepay.com/Simulator'
    
      TRANSACTIONS[:callback] = 'DIRECT3DCALLBACK'		# query needed?

      # need update in parent 
      self.homepage_url = 'http://www.sagepay.com'
      self.display_name = 'SagePay'

      # extend this to put in optional use_3ds request
      def add_credit_card(post, credit_card)
        super(post,credit_card)
        add_pair(post, :Apply3DSecure, credit_card.use_3ds ? "1" : "0")
      end

      # the core form for 3dsecure verification requests (sent to bank)
      def form_for_3dsecure_verification(params)
        requires!(params, "ACSURL", "PAReq", "MD")
        lambda do |nextstage_url,submit_element|
          [ "<form action='" + params["ACSURL"] + "' method='post'>",
            "<input type='hidden' name='PaReq' value='" + params["PAReq"] +"'/>",
            "<input type='hidden' name='TermUrl' value='" + nextstage_url + "'/>",
            "<input type='hidden' name='MD' value='" + params["MD"] + "'/>",
            submit_element,
            "</form>"].join 
	end
      end
     
      # form for sending 3dsecure auth results back to Protx 
      # use 'target="_top"' if you want the confirmation to be outside any iframe
      def form_for_3dsecure_callback(params, nextstage_url, auth_token, target_attrib = "")
        <<EOF
<SCRIPT LANGUAGE="Javascript"> function OnLoadEvent() { document.form.submit(); }</SCRIPT>
<HTML>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
<title>3D-Secure Redirect</title>
</head>

<body OnLoad="OnLoadEvent();">
<form name="form" action="#{ nextstage_url }" method="POST" #{ target_attrib }>
  <input type="hidden" name="PaRes"  value="#{ params['PaRes'] }"/>
  <input type="hidden" name="MD"     value="#{ params['MD'] }"/>
  <input type="hidden" name="authenticity_token" value="#{ auth_token }"/>
  <NOSCRIPT>
  <center><p>Please click button below to Authorise your card</p><input type="submit" value="Go"/></p></center>
  </NOSCRIPT>
</form>
</body>
</html>
EOF
      end

      # final stage of some other transaction
      def complete_3dsecure(params)
        requires!(params, "PaRes", "MD", "VendorTxCode")
        post = {}
        add_pair(post, :MD,           params["MD"])
        add_pair(post, :PARes,        params["PaRes"])
        add_pair(post, :VendorTxCode, sanitize_order_id(params["VendorTxCode"]))
      
        commit(:callback, post)
      end
      
      # temporary over-ride, just for logging purposes. 
      def commit(action, parameters)
        response = parse( ssl_post(url_for(action), post_data(action, parameters)) )

        File.open("/tmp/protx", "a") do |f|			# careful on permissions!
          f.puts "\n\n\n ************** #{Time.now}\n"
          f.puts url_for(action).to_yaml
          f.puts "\n\n"
          parameters[:CardNumber] = "[hidden]"
          parameters[:CV2] = "[hidden]"
          f.puts parameters.to_yaml
          f.puts "\n\n"
          dummy = response.clone
          dummy["PAReq"] = "[hidden]"
          f.puts dummy.to_yaml
          f.puts "\n\n"
        end

        Response.new(response["Status"] == APPROVED, message_from(response), response,
          :test => test?,
          :authorization => authorization_from(response, parameters, action),
          :avs_result => { 
            :street_match => AVS_CVV_CODE[ response["AddressResult"] ],
            :postal_match => AVS_CVV_CODE[ response["PostCodeResult"] ],
          },
          :cvv_result => AVS_CVV_CODE[ response["CV2Result"] ]
        )
      end
    end
  end
end

