/* Shared theme controls. All submitted amounts and availability are validated by Rails. */
(() => {
  if (window.OperationsUI) return;
  const UI = window.OperationsUI = {
    async alert(text, icon = 'error') {
      // Native dialogs occupy the browser top layer; render SweetAlert inside them.
      return Swal.fire({ text, icon, confirmButtonText: 'Entendido', target: document.querySelector('dialog[open]') || document.body });
    },
    async request(url, options = {}) {
      const response = await fetch(url, { credentials: 'same-origin', ...options,
        headers: { Accept: 'application/json', 'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || '', ...options.headers } });
      const payload = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(payload.error || (response.status === 401 ? 'Tu sesión terminó. Vuelve a iniciar sesión.' : 'No se pudo guardar. Revisa los datos e inténtalo nuevamente.'));
      return { payload, location: response.headers.get('Location') };
    },
    async submit(form) {
      if (form.dataset.saving) return;
      form.dataset.saving = 'true';
      let navigating = false;
      const buttons = [...form.querySelectorAll('[type=submit], button:not([type])')];
      buttons.forEach(button => button.disabled = true);
      try {
        if (form.dataset.confirm) {
          const answer = await Swal.fire({ text: form.dataset.confirm, icon: 'question', showCancelButton: true,
            confirmButtonText: 'Confirmar', cancelButtonText: 'Volver', target: document.querySelector('dialog[open]') || document.body });
          if (!answer.isConfirmed) return;
        }
        const result = await UI.request(form.action, { method: form.method.toUpperCase(), body: new FormData(form) });
        if (form.hasAttribute('data-catalog-form')) {
          form.closest('dialog').close();
          $('#operationsTable').DataTable().ajax.reload(null, false);
          await UI.alert('Registro guardado', 'success');
        } else {
          sessionStorage.setItem('operations-notice', 'Operación guardada');
          navigating = true;
          window.location.assign(result.location || window.location.href);
        }
      } catch (error) { await UI.alert(error.message); }
      finally { if (!navigating) { delete form.dataset.saving; buttons.forEach(button => button.disabled = false); } }
    }
  };

  document.addEventListener('submit', event => {
    const form = event.target;
    if (!form.closest('.ops') || form.hasAttribute('data-pos-form') || form.hasAttribute('data-appointment-editor') || form.method.toLowerCase() === 'get') return;
    event.preventDefault(); UI.submit(form);
  });

  document.addEventListener('click', async event => {
    const removeEmployee = event.target.closest('[data-employee-delete]');
    if (removeEmployee && !removeEmployee.disabled) {
      removeEmployee.disabled = true;
      try {
        const answer = await Swal.fire({ title: 'Eliminar empleado', text: '¿Eliminar a ' + removeEmployee.dataset.employeeName + '?', icon: 'warning', showCancelButton: true, confirmButtonText: 'Sí, eliminar', cancelButtonText: 'Cancelar', customClass: 'sweet-alerts' });
        if (!answer.isConfirmed) return;
        await UI.request(removeEmployee.dataset.employeeDelete, { method: 'DELETE' });
        $('#operationsTable').DataTable().ajax.reload(null, false);
        await UI.alert('Empleado eliminado', 'success');
      } catch (error) { await UI.alert(error.message); }
      finally { removeEmployee.disabled = false; }
      return;
    }
    const removeSale = event.target.closest('[data-sale-delete]');
    if (removeSale && !removeSale.disabled) {
      removeSale.disabled = true;
      try {
        const answer = await Swal.fire({ title: 'Eliminar venta', text: '¿Eliminar la venta ' + removeSale.dataset.saleFolio + '?', icon: 'warning', showCancelButton: true, confirmButtonText: 'Sí, eliminar', cancelButtonText: 'Cancelar', customClass: 'sweet-alerts' });
        if (!answer.isConfirmed) return;
        await UI.request(removeSale.dataset.saleDelete, { method: 'DELETE' });
        $('#operationsTable').DataTable().ajax.reload(null, false);
        await UI.alert('Venta eliminada', 'success');
      } catch (error) { await UI.alert(error.message); }
      finally { removeSale.disabled = false; }
      return;
    }
    const removeCatalog = event.target.closest('[data-catalog-delete]');
    if (removeCatalog && !removeCatalog.disabled) {
      removeCatalog.disabled = true;
      try {
        const kind = removeCatalog.dataset.catalogKind || 'registro';
        const answer = await Swal.fire({ title: 'Eliminar ' + kind, text: '¿Eliminar ' + removeCatalog.dataset.catalogName + '?', icon: 'warning', showCancelButton: true, confirmButtonText: 'Sí, eliminar', cancelButtonText: 'Cancelar', customClass: 'sweet-alerts' });
        if (!answer.isConfirmed) return;
        await UI.request(removeCatalog.dataset.catalogDelete, { method: 'DELETE' });
        $('#operationsTable').DataTable().ajax.reload(null, false);
        await UI.alert(kind.charAt(0).toUpperCase() + kind.slice(1) + ' eliminado', 'success');
      } catch (error) { await UI.alert(error.message); }
      finally { removeCatalog.disabled = false; }
      return;
    }
    const close = event.target.closest('[data-close-dialog]');
    if (close) close.closest('dialog').close();
    const edit = event.target.closest('[data-catalog-edit]');
    const create = event.target.closest('[data-catalog-new]');
    if (edit || create) {
      const root = document.querySelector('[data-catalog]');
      const dialog = document.getElementById('catalog-dialog');
      const form = dialog.querySelector('form');
      form.reset(); form.querySelector('[name="_method"]')?.remove();
      form.action = root.dataset.catalogUrl;
      document.getElementById('catalog-title').textContent = edit ? 'Editar registro' : 'Agregar registro';
      if (edit) {
        const record = JSON.parse(edit.dataset.catalogEdit);
        form.action += '/' + record.id;
        const method = document.createElement('input'); method.type = 'hidden'; method.name = '_method'; method.value = 'patch'; form.append(method);
        for (const [key, value] of Object.entries(record)) {
          const fields = form.querySelectorAll(`[name="${root.dataset.catalog}[${key}]"]`);
          fields.forEach(field => { if (field.type === 'checkbox') field.checked = value; else if (field.type !== 'hidden') field.value = value ?? ''; });
        }
      }
      dialog.showModal();
    }
    const removeSlot = event.target.closest('[data-remove-slot]');
    if (removeSlot) {
      const row = removeSlot.closest('[data-schedule-row]');
      if (row.parentElement.children.length > 1) row.remove();
      else row.querySelectorAll('input,select').forEach(field => field.value = '');
    }
    if (event.target.closest('[data-add-slot]')) {
      const rows = document.querySelector('[data-schedule-rows]');
      const row = rows.firstElementChild.cloneNode(true);
      const index = String(Date.now());
      row.querySelectorAll('input,select').forEach(field => { field.value = ''; field.name = field.name.replace(/slots\[\d+\]/, `slots[${index}]`); field.id = field.id.replace(/\d+$/, index); });
      row.querySelectorAll('label').forEach(label => label.htmlFor = label.htmlFor.replace(/\d+$/, index));
      rows.append(row);
    }
  });

  document.addEventListener('DOMContentLoaded', () => {
    const flash = document.querySelector('[data-ops-flash]');
    const saved = sessionStorage.getItem('operations-notice'); sessionStorage.removeItem('operations-notice');
    if (flash || saved) Swal.fire({ toast: true, position: 'top-end', timer: 3000, showConfirmButton: false,
      icon: flash?.dataset.icon || 'success', text: flash?.dataset.opsFlash || saved });
    const table = document.querySelector('[data-ops-table]');
    if (table) {
      const count = table.querySelectorAll('thead th').length;
      $.fn.dataTable.ext.errMode = 'none';
      $(table).on('error.dt', () => UI.alert('No se pudo cargar la tabla. Recarga la página para volver a intentarlo.'));
      $(table).DataTable({ ...AdminDatatable.tableDefaults, serverSide: true, processing: true,
        ajax: table.dataset.opsTable, columns: Array.from({ length: count }, (_, i) => ({ data: i, orderable: i !== count - 1 && !(table.dataset.opsTable.includes('/sales/') && i === 1) })),
        order: [], dom: AdminDatatable.dom, lengthMenu: AdminDatatable.lengthMenu, pageLength: AdminDatatable.pageLength,
        language: AdminDatatable.language, initComplete() { AdminDatatable.initComplete(this.api()); } });
    }
    initializeCalendar();
    document.querySelectorAll('.ops-time-field input[type=time]').forEach(input => {
      input.addEventListener('click', () => {
        if (input.disabled || typeof input.showPicker !== 'function') return;
        try { input.showPicker(); } catch (_) { /* picker already open or unsupported */ }
      });
    });
  });

  function initializeCalendar() {
    const root = document.getElementById('employee-calendar'); if (!root) return;
    const columns = JSON.parse(document.getElementById('calendar-data').textContent);
    const openAppointment = detail => window.dispatchEvent(new CustomEvent('appointment-open', { detail }));
    document.querySelector('[data-new-booking]')?.addEventListener('click', () => openAppointment({ start: root.dataset.date + 'T09:00' }));
    let moving = false;
    async function moveAppointment(info, employeeId) {
      if (moving) { info.revert(); return; }
      moving = true;
      try {
        await UI.request('/operations/appointments/' + info.event.id + '/reschedule', { method: 'PATCH',
          headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ appointment: {
            employee_id: employeeId, starts_at: info.event.start.toISOString().slice(0, 19), ends_at: info.event.end.toISOString().slice(0, 19)
          } }) });
        sessionStorage.setItem('operations-notice', 'Cita reprogramada'); window.location.reload();
      } catch (error) { info.revert(); moving = false; await UI.alert(error.message); }
    }
    columns.forEach(column => {
      const element = root.querySelector(`[data-employee-calendar="${column.id}"]`);
      const colors = { scheduled: '#4361ee', completed: '#00ab55', cancelled: '#888ea8', no_show: '#888ea8' };
      const overlaps = (start, end, range) => start < new Date(range.end + 'Z') && end > new Date(range.start + 'Z');
      const selectable = range => !column.blocked.some(block => overlaps(range.start, range.end, block)) &&
        !column.events.some(event => ['scheduled', 'completed'].includes(event.status) && overlaps(range.start, range.end, event));
      const calendar = new FullCalendar.Calendar(element, {
        initialView: 'timeGridDay', initialDate: root.dataset.date, headerToolbar: false, dayHeaders: false,
        // Offset-free civil times supplied by Rails are deliberately rendered in UTC
        // to keep the business clock independent from the browser's time zone.
        timeZone: 'UTC', locale: 'es', allDaySlot: false, height: 'auto', expandRows: false,
        slotDuration: '00:30:00', snapDuration: '00:15:00', slotMinTime: '08:00:00', slotMaxTime: '20:00:00', scrollTime: '08:00:00',
        slotLabelFormat: { hour: '2-digit', minute: '2-digit', hour12: false }, eventTimeFormat: { hour: '2-digit', minute: '2-digit', hour12: false },
        selectable: root.dataset.bookable === 'true', selectAllow: selectable,
        editable: root.dataset.bookable === 'true', droppable: root.dataset.bookable === 'true', eventDurationEditable: false,
        eventAllow: () => !moving,
        eventDrop: info => moveAppointment(info, column.id),
        eventReceive: info => moveAppointment(info, column.id),
        events: [ ...column.blocked.map(block => ({ ...block, display: 'background', classNames: ['ops-unavailable'] })),
          ...column.events.map(event => ({ ...event, durationEditable: false, backgroundColor: colors[event.status], borderColor: colors[event.status] })) ],
        select(range) {
          openAppointment({ employee_id: column.id, start: range.startStr.slice(0, 16) }); calendar.unselect();
        },
        eventContent(info) {
          if (info.event.display === 'background') return { domNodes: [] };
          const content = document.createElement('div');
          const title = document.createElement('strong'); title.textContent = info.timeText + ' · ' + info.event.title;
          const services = document.createElement('div'); services.className = 'ops-event-services'; services.textContent = info.event.extendedProps.services || '';
          content.append(title, services); return { domNodes: [content] };
        },
        eventDidMount(info) {
          if (info.event.display === 'background') return;
          info.el.title = `${info.event.title} · ${info.event.extendedProps.services}`;
          info.el.setAttribute('tabindex', '0'); info.el.setAttribute('role', 'button');
          info.el.addEventListener('keydown', event => { if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); info.el.click(); } });
        },
        eventClick(info) {
          if (!info.event.id) return;
          openAppointment({ ...info.event.extendedProps, id: info.event.id, editable: info.event.startEditable,
            start: info.event.start.toISOString().slice(0, 16), end: info.event.end.toISOString().slice(0, 16) });
        }
      });
      calendar.render();
      new ResizeObserver(() => calendar.updateSize()).observe(element.parentElement);
    });
  }

  document.addEventListener('alpine:init', () => {
    Alpine.data('operationsPos', () => ({
      currency: 'MXN', baseCurrency: 'MXN', exchangeRate: null, discountPercent: 0, checkoutKey: null,
      payments: [{ key: 1, method: 'cash', amount: '0' }], nextPaymentKey: 1,
      paymentMethods: [{ value: 'cash', label: 'Efectivo' }, { value: 'card', label: 'Tarjeta' }, { value: 'transfer', label: 'Transferencia' }], client: null, appointmentId: null, notes: '', items: [], employees: [], newClient: false,
      customer: { name: '', phone: '', email: '' }, clientQuery: '',
      clientResults: [], clientLoading: false, clientSearched: false, saving: false,
      clientRequest: 0, nextKey: 0,
      init() {
        const initial = JSON.parse(document.getElementById('pos-data').textContent);
        this.baseCurrency = initial.base_currency; this.exchangeRate = initial.exchange_rate;
        this.discountPercent = Number(initial.discount_percent) || 0; this.checkoutKey = initial.checkout_key;
        this.currency = initial.currency; this.client = initial.client; this.appointmentId = initial.appointment_id; this.notes = initial.notes || ''; this.employees = initial.employees || [];
        this.items = initial.items.map(item => ({ ...item, employee_id: item.employee_id ? String(item.employee_id) : '', key: ++this.nextKey }));
        this.initServicePicker();
      },
      destroy() {
        const picker = window.jQuery?.('#sale-service-picker');
        if (picker?.hasClass('select2-hidden-accessible')) picker.off('select2:select').select2('destroy');
      },
      initServicePicker() {
        const el = document.getElementById('sale-service-picker');
        if (!el || !window.jQuery) return;
        const picker = window.jQuery(el);
        if (picker.hasClass('select2-hidden-accessible')) picker.select2('destroy');
        picker.select2({
          theme: 'bootstrap',
          placeholder: 'Buscar y agregar un servicio',
          allowClear: true,
          width: '100%',
          dropdownParent: window.jQuery(document.body),
          language: { noResults: () => 'No se encontraron servicios', searching: () => 'Buscando…' },
          ajax: {
            url: '/operations/services/lookup',
            dataType: 'json',
            delay: 250,
            headers: { Accept: 'application/json' },
            data: params => ({ q: params.term || '' }),
            processResults: data => ({
              results: (Array.isArray(data) ? data : []).map(service => ({
                id: service.id,
                text: service.name + ' · ' + service.duration_minutes + ' min · ' + this.money(this.convertPrice(service.price, this.baseCurrency)),
                service
              }))
            })
          }
        });
        picker.on('select2:select', event => {
          if (event.params.data.service) this.addService(event.params.data.service);
          picker.val(null).trigger('change');
        });
      },
      money(value) { return new Intl.NumberFormat('es-MX', { style: 'currency', currency: this.currency }).format(value); },
      cents(value) { return Math.round((Number(this.parseMoneyInput(value)) || 0) * 100); },
      parseMoneyInput(value) {
        const text = String(value ?? '').replace(/,/g, '').replace(/[^\d.]/g, '');
        if (!text) return '';
        const firstDot = text.indexOf('.');
        if (firstDot === -1) return text.replace(/^0+(?=\d)/, '') || '0';
        const intPart = text.slice(0, firstDot).replace(/^0+(?=\d)/, '') || '0';
        return intPart + '.' + text.slice(firstDot + 1).replace(/\./g, '').slice(0, 2);
      },
      formatMoneyInput(value) {
        const parsed = this.parseMoneyInput(value);
        if (parsed === '') return '';
        const [intPart, decPart] = parsed.split('.');
        const grouped = intPart.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
        return parsed.includes('.') ? grouped + '.' + (decPart ?? '') : grouped;
      },
      setPaymentAmount(payment, event) {
        const input = event.target, cursor = input.selectionStart;
        const digitsBefore = String(input.value).slice(0, cursor).replace(/[^\d.]/g, '').length;
        payment.amount = this.parseMoneyInput(input.value);
        this.$nextTick(() => {
          const formatted = this.formatMoneyInput(payment.amount);
          if (input.value !== formatted) input.value = formatted;
          let pos = 0, seen = 0;
          while (pos < formatted.length && seen < digitsBefore) { if (/[\d.]/.test(formatted[pos])) seen++; pos++; }
          try { input.setSelectionRange(pos, pos); } catch (_) { /* selection not available */ }
        });
      },
      lineDiscount(item) {
        const base = Number(item.quantity) * this.cents(item.unit_price), percent = Math.round((Number(this.discountPercent) || 0) * 100);
        if (!Number.isFinite(base) || !Number.isFinite(percent)) return 0;
        return Number((BigInt(Math.trunc(base)) * BigInt(percent) + 5000n) / 10000n);
      },
      lineBase(item) { return Number(item.quantity) * this.cents(item.unit_price) - this.lineDiscount(item); },
      convertPrice(value, source) {
        if (source === this.currency) return Number(value);
        const rate = BigInt(Math.round(Number(this.exchangeRate) * 1000000)), cents = BigInt(this.cents(value));
        if (rate <= 0n) return 0;
        const numerator = source === 'MXN' ? cents * 1000000n : cents * rate;
        const denominator = source === 'MXN' ? rate : 1000000n;
        return Number((numerator + denominator / 2n) / denominator) / 100;
      },
      async changeCurrency(currency) {
        if (currency === this.currency) return;
        if (!(Number(this.exchangeRate) > 0)) {
          document.getElementById('sale-currency').value = this.currency;
          return UI.alert('Configura el tipo de cambio en Configuración antes de convertir la moneda.');
        }
        const previous = this.currency; this.currency = currency;
        this.items.forEach(item => {
          // Preserve the price's source to avoid cumulative rounding on currency switches.
          if (!item.priceSource || Number(item.unit_price) !== item.lastConvertedPrice) item.priceSource = { currency: previous, value: item.unit_price };
          item.unit_price = this.convertPrice(item.priceSource.value, item.priceSource.currency).toFixed(2);
          item.lastConvertedPrice = Number(item.unit_price);
        });
        this.payments.forEach(payment => { payment.amount = '0'; });
      },
      addPayment() {
        if (this.payments.length >= 2) return;
        this.payments.push({ key: ++this.nextPaymentKey, method: this.paymentMethods.find(method => !this.payments.some(payment => payment.method === method.value)).value, amount: '0' });
      },
      get totalPaid() { return this.payments.reduce((sum, payment) => sum + this.cents(payment.amount), 0); },
      get change() { return Math.max(0, this.totalPaid - this.totals.total); },
      get paymentError() {
        if (this.payments.some(payment => payment.amount === '' || !Number.isFinite(Number(payment.amount)) || Number(payment.amount) < 0 || ((this.totals.total > 0 || this.payments.length > 1) && this.cents(payment.amount) === 0))) return 'Ingresa el monto de cada pago.';
        if (new Set(this.payments.map(payment => payment.method)).size !== this.payments.length) return 'Selecciona métodos de pago distintos.';
        if (this.totalPaid < this.totals.total) return 'Falta pagar ' + this.money((this.totals.total - this.totalPaid) / 100) + '.';
        const cash = this.payments.find(payment => payment.method === 'cash');
        if (this.change > 0 && (!cash || this.change >= this.cents(cash.amount))) return 'Solo se puede dar cambio del efectivo aplicado a la venta.';
        return '';
      },
      lineTotal(item) { return this.lineBase(item); },
      get totals() {
        return this.items.reduce((sum, item) => ({ subtotal: sum.subtotal + Number(item.quantity) * this.cents(item.unit_price),
          discount: sum.discount + this.lineDiscount(item), total: sum.total + this.lineTotal(item) }),
        { subtotal: 0, discount: 0, total: 0 });
      },
      async searchClients() {
        const request = ++this.clientRequest; this.clientLoading = true; this.clientSearched = true;
        try { const { payload } = await UI.request('/operations/clients/lookup?q=' + encodeURIComponent(this.clientQuery)); if (request === this.clientRequest) this.clientResults = payload; }
        catch (error) { if (request === this.clientRequest) { this.clientResults = []; await UI.alert(error.message); } }
        finally { if (request === this.clientRequest) this.clientLoading = false; }
      },
      chooseClient(client) { ++this.clientRequest; this.clientLoading = false; this.client = client; this.clientQuery = ''; this.clientResults = []; this.clientSearched = false; },
      employeesFor() { return this.employees; },
      addService(service) {
        const existing = this.items.find(item => item.service_id === service.id && !item.appointment_service_id);
        if (existing) existing.quantity = Number(existing.quantity) + 1;
        else {
          const previous = this.items[this.items.length - 1];
          this.items.push({ key: ++this.nextKey, service_id: service.id, description: service.name, employee_id: previous?.employee_id || '', quantity: 1, unit_price: this.convertPrice(service.price, this.baseCurrency).toFixed(2), priceSource: { currency: this.baseCurrency, value: service.price }, lastConvertedPrice: this.convertPrice(service.price, this.baseCurrency), discount_amount: '0.00' });
        }
      },
      async save(event) {
        if (this.saving || !event.target.reportValidity()) return;
        if (!this.items.length || (!this.newClient && !this.client)) return UI.alert('Selecciona un cliente y al menos un servicio.');
        if (this.items.some(item => this.lineBase(item) < 0)) return UI.alert('El descuento no puede superar el importe del servicio.');
        if (this.paymentError) return UI.alert(this.paymentError);
        this.saving = true;
        try {
          const sale = { notes: this.notes, appointment_id: this.appointmentId, currency: this.currency, exchange_rate: this.exchangeRate, discount_percent: Number(this.discountPercent) || 0, checkout_key: this.checkoutKey, payments: this.payments.map(({ method, amount }) => ({ method, amount: this.parseMoneyInput(amount) })),
            items: this.items.map(({ key, priceSource, lastConvertedPrice, discount_amount, ...item }) => item) };
          if (this.newClient) sale.new_client = this.customer; else sale.client_id = this.client.id;
          const result = await UI.request(event.target.action, { method: event.target.querySelector('[name="_method"]').value.toUpperCase(),
            headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ sale }) });
          sessionStorage.setItem('operations-notice', 'Venta guardada'); window.location.assign(result.location);
        } catch (error) { this.saving = false; await UI.alert(error.message); }
      }
    }));
  });
})();
