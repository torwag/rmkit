//#define DEBUG_INPUT_EVENT 1

namespace input:
  class Event:
    public:
    def update(input_event data)
    def print_event(input_event &data):
      #ifdef DEBUG_INPUT_EVENT
      printf("Event: time %ld, type: %x, code :%x, value %d\n", \
        data.time.tv_sec, data.type, data.code, data.value)
      #endif
      return

    def finalize():
      pass

    virtual ~Event() = default

  class SynEvent: public Event:
    public:
    int x = -1, y = -1
    int left = 0, right = 0, middle = 0
    int eraser = 0
    int pressure = -1, tilt_x = -1, tilt_y = -1
    Event *original
    SynEvent(){}

    def set_original(Event *ev):
      self.original = ev

  class KeyEvent: public Event:
    public:
    int key, is_pressed

  class ButtonEvent: public Event:
    public:
    int key = -1, is_pressed = 0
    ButtonEvent() {}
    def update(input_event data):
      if data.type == EV_KEY:
        self.key = data.code
        self.is_pressed = data.value

      self.print_event(data)

    def marshal(ButtonEvent &prev):
      KeyEvent key_ev
      key_ev.key = self.key
      key_ev.is_pressed = self.is_pressed
      return key_ev

  class TouchEvent: public Event:
    public:
    int x, y, left
    TouchEvent() {}

    handle_abs(input_event data):
      switch data.code:
        case ABS_MT_POSITION_X:
          self.x = (MTWIDTH - data.value)*MT_X_SCALAR
          break
        case ABS_MT_POSITION_Y:
          self.y = (MTHEIGHT - data.value)*MT_Y_SCALAR
          break
        case ABS_MT_TRACKING_ID:
          self.left = data.value > -1
          break


    def marshal(TouchEvent &prev):
      SynEvent syn_ev;
      syn_ev.left = self.left

      // if there's no left click, we re-use the last x,y coordinate
      if !self.left:
        syn_ev.x = prev.x
        syn_ev.y = prev.y
      else:
        syn_ev.x = self.x
        syn_ev.y = self.y

      self.x = syn_ev.x
      self.y = syn_ev.y
      syn_ev.set_original(new TouchEvent(*self))

      return syn_ev

    def update(input_event data):
      self.print_event(data)
      switch data.type:
        case 3:
          self.handle_abs(data)

  class MouseEvent: public Event:
    public:
    MouseEvent() {}
    int x = 0, y = 0
    signed char dx = 0, dy = 0
    int left = 0 , right = 0 , middle = 0
    static int width, height

    static void set_screen_size(int w, h):
      width = w
      height = h

    def update(input_event data):
      self.print_event(data)

    def marshal(MouseEvent &prev):
      self.x = prev.x + self.dx
      self.y = prev.y + self.dy

      if self.y < 0:
        self.y = 0
      if self.x < 0:
        self.x = 0

      if self.y >= self.height - 1:
        self.y = (int) self.height - 5

      if self.x >= self.width - 1:
        self.x = (int) self.width - 5

      o_x = self.x
      o_y = self.height - self.y

      if o_y >= self.height - 1:
        o_y = self.height - 5

      SynEvent syn_ev;
      syn_ev.x = o_x
      syn_ev.y = o_y
      syn_ev.left = self.left
      syn_ev.right = self.right

      if self.right:
        syn_ev.eraser = ERASER_STYLUS
      if self.middle:
        syn_ev.eraser = ERASER_RUBBER

      syn_ev.set_original(new MouseEvent(*self))
      return syn_ev
  int MouseEvent::width = 0
  int MouseEvent::height = 0

  class WacomEvent: public Event:
    public:
    int x = -1, y = -1, pressure = -1
    int tilt_x = -1, tilt_y = -1
    int btn_touch = -1
    int eraser = -1

    def marshal(WacomEvent &prev):
      SynEvent syn_ev;
      syn_ev.x = self.x
      syn_ev.y = self.y

      if self.btn_touch == -1:
        self.btn_touch = prev.btn_touch
      if self.eraser == -1:
        self.eraser = prev.eraser
      if self.pressure == -1 || self.pressure == 0:
        self.pressure = prev.pressure

      syn_ev.pressure = self.pressure
      syn_ev.tilt_x = self.tilt_x
      syn_ev.tilt_y = self.tilt_y
      syn_ev.left = self.btn_touch
      syn_ev.eraser = self.eraser
      syn_ev.set_original(new WacomEvent(*self))
      return syn_ev

    handle_key(input_event data):
      switch data.code:
        case BTN_TOUCH:
          self.btn_touch = data.value
          break
        case BTN_TOOL_RUBBER:
          self.eraser = data.value ? ERASER_RUBBER : 0
          break
        case BTN_STYLUS:
          self.eraser = data.value ? ERASER_STYLUS : 0
          break

    handle_abs(input_event data):
      switch data.code:
        case ABS_Y:
          self.x = data.value * WACOM_X_SCALAR
          break
        case ABS_X:
          self.y = (WACOMHEIGHT - data.value) * WACOM_Y_SCALAR
          break
        case ABS_TILT_X:
          self.tilt_x = data.value
          break
        case ABS_TILT_Y:
          self.tilt_y = data.value
          break
        case ABS_PRESSURE:
          self.pressure = data.value
          break

    update(input_event data):
      self.print_event(data)
      switch data.type:
        case 1:
          self.handle_key(data)
        case 3:
          self.handle_abs(data)

