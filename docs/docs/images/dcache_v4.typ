#import "@preview/cetz:0.1.1"
#import "@preview/finite:0.3.0"

#set page(height: auto, width: auto, margin: (rest: 1cm))
#set text(size: 7pt)
#show raw: set text(font: ("FiraCode Nerd Font", "monospace"))
#show raw.where(block: false): it => box(text(size: 1.2em)[#it], fill: luma(94.12%, 50%), outset: (y: 3pt), inset: (x: 3pt, y: 0pt), radius: 2pt)

#figure({
  cetz.canvas({
    import cetz.draw: set-style, line
    import finite.draw: state, transitions, transition

    let r = 6

    state((0, 0), "IDLE", name: "IDLE")
    state((r, 0), "LOOKUP", name: "LOOKUP")
    state((r, -5/8*r), "REQW", name: "REQW")
    state((3/4*r, -r), "SEND", name: "SEND")
    state((1/4*r, -r), "REQR", name: "REQR")
    state((0, -5/8*r), "RECV", name: "RECV")
    state((r/2, r/2), "UNCACHED", name: "UNCACHED")

    let efsm-label(ev, act) = {
      set grid(inset: (x: .5em, y: .5em))
      set stack(spacing: .5em)
      grid(
        columns: 1,
        align: center + horizon,
        ev,
        grid.hline(),
        act
      )
    }

    transition("IDLE", "LOOKUP", curve: 0.2, label: 
`!collision
R/W`
    )
    transition("LOOKUP", "LOOKUP", label: `hit && R/W && !collision`)
    transition("LOOKUP", "IDLE", curve: 0.3, label: 
`collision || !valid 
|| (valid && uncached)`
)
    transition("LOOKUP", "REQW", curve: 0, label: 
`miss && 
need_replace`)
    transition("LOOKUP", "REQR", curve: 0, label: 
`miss && !need_replace`)
    transition("REQW", "SEND", curve: 0, label: `wr_rdy`)
    transition("REQW", "REQW", anchor: right, label: (text: `!wr_rdy`, dist: 0.6))
    transition("SEND", "REQR", curve: 0, label: `!rd_rdy`)
    transition("SEND", "RECV", curve: 0, label: `rd_rdy`)
    transition("REQR", "REQR", anchor: bottom, label: `!rd_rdy`)
    transition("REQR", "RECV", curve: 0, label: `rd_rdy`)
    transition("RECV", "RECV", anchor: left, label: (text: `!recv_fin`, dist: 0.7))
    transition("RECV", "IDLE", curve: 0, label: `recv_fin`)
    transition("IDLE", "UNCACHED", curve: 0.3, label: `valid && !op && uncached`)
    transition("UNCACHED", "UNCACHED", anchor: right, label: (text: `!recv_fin`, dist: 0.7))
    transition("UNCACHED", "IDLE", curve: 0.3, label: (pos: 0.3, text: `recv_fin`))
  })
})
