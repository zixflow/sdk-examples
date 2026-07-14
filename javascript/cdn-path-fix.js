// The npm UMD build resolves lazy chunks to cdp.zixflow.com/analytics-next/bundles/
// (404). Rewrite those script URLs to the matching jsDelivr UMD folder.
;(function () {
  var umdBase =
    'https://cdn.jsdelivr.net/npm/@zixflow/analytics-browser@1.1.5/dist/umd/'
  var badPrefixes = [
    'https://cdp.zixflow.com/analytics-next/bundles/',
    'https://cdp.zixflow.com/v1/analytics-js/',
  ]

  function rewrite(url) {
    if (typeof url !== 'string') return url
    for (var i = 0; i < badPrefixes.length; i++) {
      if (url.indexOf(badPrefixes[i]) === 0) {
        return umdBase + url.slice(badPrefixes[i].length)
      }
    }
    return url
  }

  var desc = Object.getOwnPropertyDescriptor(HTMLScriptElement.prototype, 'src')
  if (desc && desc.set && desc.get) {
    Object.defineProperty(HTMLScriptElement.prototype, 'src', {
      configurable: true,
      enumerable: desc.enumerable,
      get: function () {
        return desc.get.call(this)
      },
      set: function (value) {
        desc.set.call(this, rewrite(value))
      },
    })
  }

  var setAttribute = Element.prototype.setAttribute
  Element.prototype.setAttribute = function (name, value) {
    if (
      this instanceof HTMLScriptElement &&
      String(name).toLowerCase() === 'src'
    ) {
      value = rewrite(value)
    }
    return setAttribute.call(this, name, value)
  }
})()
