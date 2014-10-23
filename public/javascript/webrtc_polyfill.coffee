window.WEBRTC = do ->

        vendor_prefixed_methods =
                [
                        {
                                container  : navigator,
                                methods : ["getUserMedia"]
                        },
                        {
                                container  : window,
                                methods : ["RTCPeerConnection", "RTCSessionDescription", "RTCIceCandidate"]
                        }
                ]

        # Remove browser prefixes to use WebRTC API seamlessly
        remove_vendor_prefixes: ->
                for methods in vendor_prefixed_methods
                        container = methods.container
                        for method in methods.methods
                                container[method] =
                                        container["moz" + method.capitalize()]    ||
                                        container["webkit" + method.capitalize()] ||
                                        container[method]                         ||
                                        null

        # Tell whether WebRTC is supported or not.
        # remove_vendor_prefixes should be called before
        is_supported: ->
                for methods in vendor_prefixed_methods
                        container = methods.container
                        for method in methods.methods
                                return no if not container[method]?
                yes

