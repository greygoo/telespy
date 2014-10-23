(function() {
  var acceptOffer, form, got_answer, got_ice_candidate, local_video, options, peer_connection, progress, remote_video, room_id, sendOffer, servers, socket, start_video_chat;

  local_video = null;

  remote_video = null;

  form = null;

  progress = null;

  room_id = null;

  peer_connection = null;

  socket = null;

  servers = {
    iceServers: [
      {
        url: "stun:stun.l.google.com:19302"
      }, {
        url: "stun:stun.services.mozilla.com"
      }
    ]
  };

  options = {
    optional: [
      {
        DtlsSrtpKeyAgreement: true
      }
    ]
  };

  WEBRTC.remove_vendor_prefixes();

  if (WEBRTC.is_supported()) {
    got_ice_candidate = function(message) {
      console.log("Receive ICE candidate");
      return peer_connection.addIceCandidate(new RTCIceCandidate(message.ice_candidate));
    };
    got_answer = function(message) {
      console.log("Receive answer");
      console.log("Set it as remote description");
      progress.innerHTML = "Someone is joining the room...";
      return peer_connection.setRemoteDescription(new RTCSessionDescription(message.answer));
    };
    start_video_chat = function(success_callback) {
      return navigator.getUserMedia({
        video: true,
        audio: true
      }, function(local_media_stream) {
        console.log("Got user media stream");
        local_video.src = URL.createObjectURL(local_media_stream);
        local_video.play();
        local_video.muted = true;
        form.className = "animated rotateOut";
        setTimeout(function() {
          return form.style.display = "none";
        }, 1000);
        local_video.style.display = "block";
        progress.style.display = "block";
        peer_connection = new RTCPeerConnection(servers, options);
        peer_connection.addStream(local_media_stream);
        peer_connection.onicecandidate = function(event) {
          if (event.candidate != null) {
            console.log("Create ice candidate");
            console.log("Send ice candidate ");
            return socket.send(JSON.stringify({
              type: "ice-candidate",
              ice_candidate: event.candidate,
              room_id: room_id
            }));
          }
        };
        peer_connection.onaddstream = function(media_stream_event) {
          console.log("Receive other's media stream");
          remote_video.src = URL.createObjectURL(media_stream_event.stream);
          remote_video.play();
          return remote_video.style.display = "block";
        };
        return success_callback();
      }, function(error) {
        switch (error) {
          case "PERMISSION_DENIED":
            alert("You must accept to start a video chat.");
            return form.elements["submit"].click();
          case "NOT_SUPPORTED_ERROR":
            return alert("Your browser does not support video or audio chat");
          case "MANDATORY_UNSATISFIED_ERROR":
            return alert("MANDATORY_UNSATISFIED_ERROR");
        }
      });
    };
    acceptOffer = function(offer) {
      console.log("Receive offer");
      return start_video_chat(function() {
        progress.innerHTML = "Joining the room...";
        console.log("Set it as remote description");
        return peer_connection.setRemoteDescription(new RTCSessionDescription(offer), function() {
          return peer_connection.createAnswer(function(answer) {
            console.log("Create answer");
            console.log("Set it as local description");
            return peer_connection.setLocalDescription(answer, function() {
              console.log("Send answer");
              return socket.send(JSON.stringify({
                type: "answer",
                answer: answer,
                room_id: room_id
              }));
            }, function() {});
          }, function() {
            return alert("error");
          });
        });
      });
    };
    sendOffer = function() {
      return start_video_chat(function() {
        progress.innerHTML = "Now tell your friend to do the same !";
        return peer_connection.createOffer(function(offer) {
          console.log("Create offer");
          return peer_connection.setLocalDescription(offer, function() {
            console.log("Set it as local description");
            console.log("Send offer");
            return socket.send(JSON.stringify({
              type: "offer",
              offer: offer,
              room_id: room_id
            }));
          });
        }, function() {});
      });
    };
    document.addEventListener("DOMContentLoaded", function() {
      form = document.getElementById("create-room");
      local_video = document.getElementById("local-video");
      remote_video = document.getElementById("remote-video");
      progress = document.getElementById("progress");
      return form.addEventListener("submit", function(event) {
        event.preventDefault();
        room_id = form.elements["room[:id]"].value;
        socket = new WebSocket("ws://" + window.location.host + "/socket");
        socket.onopen = function(event) {
          return socket.send(JSON.stringify({
            type: "connect",
            room_id: room_id
          }));
        };
        return socket.onmessage = function(event) {
          var message;
          message = JSON.parse(event.data);
          switch (message.type) {
            case "no-room":
              return sendOffer();
            case "offer":
              return acceptOffer(message.offer);
            case "answer":
              return got_answer(message);
            case "ice-candidate":
              return got_ice_candidate(message);
            case "error-room-occupied":
              return alert("This room is already occupied. Choose another room name !");
            case "other-left":
              progress.innerHTML = "Your friend left the room";
              remote_video.style.display = "none";
              return setTimeout(function() {
                return window.location = window.location.toString();
              }, 3000);
          }
        };
      });
    });
    window.addEventListener("beforeunload", function(event) {
      if (room_id != null) {
        console.log("closing...");
        socket.send(JSON.stringify({
          type: "close",
          room_id: room_id
        }));
        socket.close();
        return peer_connection.close();
      }
    });
  } else {
    alert("Unfortunately, your browser is too old and cannot handle the state-of-the-art technologies this application is using. Keep the web moving forward by upgrading your browser !");
  }

}).call(this);
