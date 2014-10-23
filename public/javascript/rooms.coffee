local_video  = null
remote_video = null
form         = null
progress     = null

room_id = null

peer_connection = null
socket          = null

servers = {
        iceServers: [
                        { url: "stun:stun.l.google.com:19302"   },
                        { url: "stun:stun.services.mozilla.com" }
                ]
        }

options = { optional: [{ DtlsSrtpKeyAgreement: true }] } # FF & Chrome interoperability

WEBRTC.remove_vendor_prefixes()

if WEBRTC.is_supported()

        got_ice_candidate = (message) ->
                console.log("Receive ICE candidate")
                peer_connection.addIceCandidate(new RTCIceCandidate(message.ice_candidate))

        got_answer = (message) ->
                console.log("Receive answer")
                console.log("Set it as remote description")
                # Set newly received answer to the remote connection description
                progress.innerHTML = "Someone is joining the room..."
                peer_connection.setRemoteDescription(new RTCSessionDescription(message.answer))

        # Get user camera then call callback
        start_video_chat = (success_callback) ->
                navigator.getUserMedia

                        video: true,
                        audio: true

                        # Success
                        (local_media_stream) ->
                                console.log("Got user media stream")

                                # Bind user media stream to video element
                                local_video.src = URL.createObjectURL(local_media_stream)
                                local_video.play()
                                local_video.muted = true # Prevent to hearing yourself
                                # form.className = "animated bounceOutRight"
                                # form.className = "animated flipOutY"
                                form.className = "animated rotateOut"
                                setTimeout( # Remove form after animation (which last 1s)
                                        -> form.style.display = "none",
                                        1000)
                                local_video.style.display = "block"
                                progress.style.display    = "block"

                                peer_connection = new RTCPeerConnection(servers, options)

                                peer_connection.addStream(local_media_stream)

                                # Send ice candidate
                                peer_connection.onicecandidate = (event) ->
                                        if event.candidate?
                                                console.log("Create ice candidate")
                                                console.log("Send ice candidate ")
                                                socket.send JSON.stringify type: "ice-candidate", ice_candidate: event.candidate, room_id: room_id

                                # Receive stream from remote peer
                                peer_connection.onaddstream = (media_stream_event) ->
                                        console.log("Receive other's media stream")
                                        remote_video.src = URL.createObjectURL(media_stream_event.stream)
                                        remote_video.play()
                                        remote_video.style.display = "block"

                                success_callback()

                        # Error
                        (error) ->
                                switch(error)
                                        when "PERMISSION_DENIED"
                                                alert("You must accept to start a video chat.") # TODO: A modal would be nicer
                                                form.elements["submit"].click() # Re-ask permission
                                        when "NOT_SUPPORTED_ERROR"
                                                alert("Your browser does not support video or audio chat")
                                        when "MANDATORY_UNSATISFIED_ERROR"
                                                alert("MANDATORY_UNSATISFIED_ERROR") # TODO:

        acceptOffer = (offer) ->
                console.log("Receive offer")

                start_video_chat ->
                        progress.innerHTML = "Joining the room..."

                        console.log("Set it as remote description")
                        # Set newly received offer to the remote connection description
                        peer_connection.setRemoteDescription new RTCSessionDescription(offer), ->

                                # Create answer of offer
                                peer_connection.createAnswer (answer) ->

                                        console.log("Create answer")
                                        console.log("Set it as local description")

                                        # Set it as local connection description
                                        peer_connection.setLocalDescription answer, ->
                                                console.log("Send answer")
                                                # Send answer to remote peer via the server
                                                socket.send JSON.stringify type: "answer", answer: answer, room_id: room_id
                                        , ->
                                , -> alert("error")

        sendOffer = ->
                start_video_chat ->
                        progress.innerHTML = "Now tell your friend to do the same !"

                        # Create communication offer
                        peer_connection.createOffer (offer) ->

                                console.log("Create offer")
                                # Set newly created offer to the local connection description
                                peer_connection.setLocalDescription offer, ->
                                        console.log("Set it as local description")
                                        console.log("Send offer")
                                        # Send offer to remote peer via the server
                                        socket.send JSON.stringify type: "offer", offer: offer, room_id: room_id
                        , ->

        document.addEventListener "DOMContentLoaded", ->

                form         = document.getElementById("create-room" )
                local_video  = document.getElementById("local-video" )
                remote_video = document.getElementById("remote-video")
                progress     = document.getElementById("progress"    )

                form.addEventListener "submit", (event) ->
                        event.preventDefault()
                        room_id = form.elements["room[:id]"].value

                        socket = new WebSocket "ws://#{window.location.host}/socket"
                        socket.onopen = (event) ->
                                socket.send JSON.stringify type: "connect", room_id: room_id

                        socket.onmessage = (event) ->
                                message = JSON.parse event.data
                                switch message.type

                                        when "no-room"
                                                sendOffer()

                                        when "offer"
                                                acceptOffer(message.offer)

                                        when "answer"
                                                got_answer(message)

                                        when "ice-candidate"
                                                got_ice_candidate(message)

                                        when "error-room-occupied"
                                                alert("This room is already occupied. Choose another room name !")

                                        when "other-left"
                                                progress.innerHTML = "Your friend left the room"
                                                remote_video.style.display = "none"
                                                setTimeout(
                                                        -> window.location = window.location.toString(), # Refresh
                                                        3000)

        window.addEventListener "beforeunload", (event) ->
                if room_id? # If room has been created
                        console.log("closing...")
                        socket.send JSON.stringify type: "close", room_id: room_id
                        socket.close()
                        peer_connection.close()
else
        alert "Unfortunately, your browser is too old and cannot handle the
 state-of-the-art technologies this application is using. Keep the web
 moving forward by upgrading your browser !"

## TODO:
# Add the WebRTC optionnal fail callbacks
# Use modal instead of alert()
