->() {
  title = 'Foobar'
  width = 34
  body {
    svg(viewbox: [0, 0, 400, 300], width: '100%', height: '100%') {
      text(
        title,
        x: width / 2, y: 28, text_anchor: 'middle',
      )
      polyline(
        fill: 'none',
        stroke: '#2563eb',
        points: ['1,3', '2,4', '3,5']
      )
    }
  }
}
