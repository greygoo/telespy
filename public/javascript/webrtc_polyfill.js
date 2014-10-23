(function() {

  window.WEBRTC = (function() {
    var vendor_prefixed_methods;
    vendor_prefixed_methods = [
      {
        container: navigator,
        methods: ["getUserMedia"]
      }, {
        container: window,
        methods: ["RTCPeerConnection", "RTCSessionDescription", "RTCIceCandidate"]
      }
    ];
    return {
      remove_vendor_prefixes: function() {
        var container, method, methods, _i, _len, _results;
        _results = [];
        for (_i = 0, _len = vendor_prefixed_methods.length; _i < _len; _i++) {
          methods = vendor_prefixed_methods[_i];
          container = methods.container;
          _results.push((function() {
            var _j, _len2, _ref, _results2;
            _ref = methods.methods;
            _results2 = [];
            for (_j = 0, _len2 = _ref.length; _j < _len2; _j++) {
              method = _ref[_j];
              _results2.push(container[method] = container["moz" + method.capitalize()] || container["webkit" + method.capitalize()] || container[method] || null);
            }
            return _results2;
          })());
        }
        return _results;
      },
      is_supported: function() {
        var container, method, methods, _i, _j, _len, _len2, _ref;
        for (_i = 0, _len = vendor_prefixed_methods.length; _i < _len; _i++) {
          methods = vendor_prefixed_methods[_i];
          container = methods.container;
          _ref = methods.methods;
          for (_j = 0, _len2 = _ref.length; _j < _len2; _j++) {
            method = _ref[_j];
            if (!(container[method] != null)) return false;
          }
        }
        return true;
      }
    };
  })();

}).call(this);
