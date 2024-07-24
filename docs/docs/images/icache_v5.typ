#import "@preview/cetz:0.1.1"
#import "@preview/finite:0.3.0"

#set page(height: auto, width: auto, margin: (rest: 1cm))
#set text(size: 7pt)
#show raw: set text(font: ("FiraCode Nerd Font", "monospace"))
#show raw.where(block: false): it => box(text(size: 1.2em)[#it], fill: luma(240), outset: (y: 3pt), inset: (x: 3pt, y: 0pt), radius: 2pt)

#figure(caption: [`icache_v5` 的状态机], {
  cetz.canvas({
    import cetz.draw: set-style
    import finite.draw: state, transitions, transition

    let r = 6

    state((0, 0), "IDLE")
    state((r, 0), "LOOKUP")
    state((r, -r*3/4), "REQUEST")
    state((0, -r*3/4), "RECEIVE")
    state((r/2, r*0.73), "CACOP")

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

    transition("IDLE", "LOOKUP", label: [`valid && !cacop_valid`])
    transition("LOOKUP", "IDLE", label: (text: [`hit && (!valid || cacop_valid)`], dist: -0.6))
    transition("LOOKUP", "REQUEST", label: [`!hit && !rd_rdy`])
    transition("LOOKUP", "RECEIVE", label: [`!hit && rd_rdy`])
    transition("REQUEST", "RECEIVE", label: [`rd_rdy`])
    transition("REQUEST", "REQUEST", anchor: bottom + right, label: `!rd_rdy`)
    transition("RECEIVE", "IDLE", label: [`ret_last && (!valid || cacop_en)`])
    // transition("RECEIVE", "LOOKUP", label: (text: [`ret_last && (!cacop_en && valid)`], pos: 0.4, dist: -0.5))
    transition("RECEIVE", "RECEIVE", anchor: bottom + left, label: `!ret_last`)
    transition("IDLE", "CACOP", label: `cacop_valid && code_is_lookup`)
    transition("CACOP", "IDLE")
    transition("LOOKUP", "LOOKUP", label: `hit && valid && !cacop_valid`)
    transition("IDLE", "IDLE", anchor: top + left)
    transition("IDLE", "REQUEST", label: (text: `uncached && !rd_rdy`, pos: 0.8))
    transition("IDLE", "RECEIVE", label: (text: `uncached && rd_rdy`, pos: 0.37))

  })
})
