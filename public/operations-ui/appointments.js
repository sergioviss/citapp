document.addEventListener('alpine:init', () => {
  Alpine.data('appointmentEditor', () => ({
    recordId: null, saleId: null, readOnly: false, saving: false, employeeId: '', startsAt: '', endsAt: '', notes: '',
    employees: [], catalog: [], snapshots: [], selectedIds: [], servicesOpen: false, serviceQuery: '',
    client: null, newClient: false, customer: { name: '', phone: '' }, clientQuery: '', clientResults: [],
    clientLoading: false, clientSearched: false, requestId: 0,
    init() {
      this.employees = JSON.parse(document.getElementById('calendar-data').textContent);
      this.catalog = JSON.parse(document.getElementById('booking-services-data').textContent);
    },
    open(record = {}) {
      ++this.requestId;
      this.recordId = record.id || null; this.saleId = record.sale_id || null;
      this.readOnly = !!record.id && !record.editable; this.saving = false;
      this.employeeId = String(record.employee_id || ''); this.startsAt = record.start || ''; this.endsAt = record.end || '';
      this.notes = record.notes || ''; this.snapshots = record.lines || [];
      this.selectedIds = this.snapshots.map(service => String(service.id));
      this.servicesOpen = false; this.serviceQuery = ''; this.client = record.client || null;
      this.newClient = false; this.customer = { name: '', phone: '' }; this.clientQuery = ''; this.clientResults = [];
      this.clientLoading = false; this.clientSearched = false;
      document.getElementById('booking-dialog').showModal();
    },
    get services() {
      const merged = new Map(this.catalog.map(service => [service.id, service]));
      this.snapshots.forEach(service => merged.set(service.id, service));
      return [...merged.values()];
    },
    get filteredServices() {
      const employee = this.employees.find(employee => String(employee.id) === this.employeeId);
      const query = this.serviceQuery.toLocaleLowerCase();
      return this.services.filter(service => employee?.service_ids.includes(service.id) && service.name.toLocaleLowerCase().includes(query));
    },
    get selectedServices() { return this.selectedIds.map(id => this.services.find(service => String(service.id) === String(id))).filter(Boolean); },
    get duration() { return this.selectedServices.reduce((total, service) => total + service.duration_minutes, 0); },
    money(value) { return new Intl.NumberFormat('es-MX', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(value); },
    calculateEnd() {
      const start = new Date(this.startsAt + ':00Z');
      this.endsAt = this.startsAt && this.duration && Number.isFinite(start.getTime()) ? new Date(start.getTime() + this.duration * 60000).toISOString().slice(0, 16) : '';
    },
    employeeChanged() {
      if (!this.saleId) {
        const employee = this.employees.find(employee => String(employee.id) === this.employeeId);
        this.selectedIds = this.selectedIds.filter(id => employee?.service_ids.includes(Number(id)));
      }
      this.calculateEnd();
    },
    async searchClients() {
      const requestId = ++this.requestId; this.clientLoading = true; this.clientSearched = true;
      try {
        const { payload } = await OperationsUI.request('/operations/clients/lookup?q=' + encodeURIComponent(this.clientQuery));
        if (requestId === this.requestId) this.clientResults = payload;
      } catch (error) { if (requestId === this.requestId) await OperationsUI.alert(error.message); }
      finally { if (requestId === this.requestId) this.clientLoading = false; }
    },
    chooseClient(client) {
      ++this.requestId; this.clientLoading = false; this.client = client; this.clientResults = []; this.clientQuery = '';
    },
    async save(event) {
      if (this.saving || this.readOnly || !event.target.reportValidity()) return;
      if (!this.selectedIds.length || (!this.newClient && !this.client) || !this.endsAt) return OperationsUI.alert('Selecciona cliente, empleado y servicios.');
      this.saving = true;
      try {
        const appointment = { employee_id: this.employeeId, starts_at: this.startsAt, ends_at: this.endsAt, notes: this.notes, service_ids: this.selectedIds };
        if (this.newClient) appointment.new_client = this.customer; else appointment.client_id = this.client.id;
        const url = this.recordId ? '/operations/appointments/' + this.recordId + '/reschedule' : '/operations/appointments';
        const { location } = await OperationsUI.request(url, { method: this.recordId ? 'PATCH' : 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ appointment }) });
        sessionStorage.setItem('operations-notice', this.recordId ? 'Cita actualizada' : 'Cita reservada'); window.location.assign(location);
      } catch (error) { this.saving = false; await OperationsUI.alert(error.message); }
    }
  }));
});
