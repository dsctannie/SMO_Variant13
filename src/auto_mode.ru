import random
import heapq
import math

class Bid:
    def __init__(self, bid_id, source_id, arrival_time):
        self.id = bid_id
        self.source_id = source_id
        self.arrival_time = arrival_time
        self.start_service_time = None
        self.end_service_time = None

class Source:
    def __init__(self, source_id, a, b):
        self.id = source_id
        self.a = a
        self.b = b

    def get_next_time(self, current_time):
        return current_time + random.uniform(self.a, self.b)

class Buffer:
    def __init__(self, capacity):
        self.capacity = capacity
        self.slots = [None] * capacity

    def put_bid(self, bid):
        for i in range(self.capacity):
            if self.slots[i] is None:
                self.slots[i] = bid
                return True
        return False

    def select_bid(self):
        best_idx = -1
        best_bid = None
        for i in range(self.capacity):
            bid = self.slots[i]
            if bid is not None:
                if best_bid is None:
                    best_bid = bid
                    best_idx = i
                else:
                    if bid.source_id < best_bid.source_id:
                        best_bid = bid
                        best_idx = i
                    elif bid.source_id == best_bid.source_id:
                        if bid.arrival_time > best_bid.arrival_time:
                            best_bid = bid
                            best_idx = i
        if best_idx != -1:
            self.slots[best_idx] = None
            return best_bid
        return None

class Device:
    def __init__(self, device_id, mean_time):
        self.id = device_id
        self.mean_time = mean_time
        self.busy = False
        self.current_bid = None

    def is_free(self):
        return not self.busy

    def serve(self, bid, current_time):
        self.busy = True
        self.current_bid = bid
        service_time = random.expovariate(1.0 / self.mean_time)
        return current_time + service_time

    def release(self):
        self.busy = False
        self.current_bid = None

class DispatcherSelect:
    def __init__(self, buffer, devices):
        self.buffer = buffer
        self.devices = devices

    def select_device(self):
        for dev in self.devices:
            if dev.is_free():
                return dev
        return None

def trigger_service(current_time, buffer, dispatcher, event_queue, stats=None):
    free_dev = dispatcher.select_device()
    if free_dev:
        bid_to_serve = buffer.select_bid()
        if bid_to_serve:
            bid_to_serve.start_service_time = current_time 
            end_time = free_dev.serve(bid_to_serve, current_time)
            # Передаем кортеж (прибор, время начала)
            heapq.heappush(event_queue, (end_time, "END_SERVICE", (free_dev, current_time)))

class Statistics:
    def __init__(self, num_sources, num_devices):
        self.num_sources = num_sources
        self.num_devices = num_devices
        
        self.generated = {i+1: 0 for i in range(num_sources)}
        self.refused = {i+1: 0 for i in range(num_sources)}
        self.waiting_times = {i+1: [] for i in range(num_sources)}
        self.service_times = {i+1: [] for i in range(num_sources)}
        self.total_times = {i+1: [] for i in range(num_sources)}
        
        self.device_busy_time = {i+1: 0.0 for i in range(num_devices)}
        self.total_model_time = 0.0

    def record_generated(self, source_id):
        self.generated[source_id] += 1

    def record_refused(self, source_id):
        self.refused[source_id] += 1

    def record_served(self, bid):
        wait_time = bid.start_service_time - bid.arrival_time
        serv_time = bid.end_service_time - bid.start_service_time
        total_time = bid.end_service_time - bid.arrival_time
        
        self.waiting_times[bid.source_id].append(wait_time)
        self.service_times[bid.source_id].append(serv_time)
        self.total_times[bid.source_id].append(total_time)

    def record_device_busy(self, device_id, busy_time):
        self.device_busy_time[device_id] += busy_time

    def print_summary(self):
        print("\n" + "="*110)
        print("СВОДНАЯ ТАБЛИЦА РЕЗУЛЬТАТОВ (ОР1) - Вариант 13")
        print("="*110)
        
        print("\nТаблица 1. Характеристики источников ВС")
        print(f"{'Источник':<10} | {'Сгенерировано':<14} | {'Отказов':<8} | {'P_отк':<8} | {'T_преб':<8} | {'T_ож':<8} | {'T_обсл':<8} | {'D_ож':<8} | {'D_обсл':<8}")
        print("-" * 115)
        
        for i in range(1, self.num_sources + 1):
            gen = self.generated[i]
            ref = self.refused[i]
            p_ref = ref / gen if gen > 0 else 0
            
            t_wait = sum(self.waiting_times[i]) / len(self.waiting_times[i]) if self.waiting_times[i] else 0
            t_serv = sum(self.service_times[i]) / len(self.service_times[i]) if self.service_times[i] else 0
            t_total = sum(self.total_times[i]) / len(self.total_times[i]) if self.total_times[i] else 0
            
            d_wait = (sum([x**2 for x in self.waiting_times[i]]) / len(self.waiting_times[i]) - t_wait**2) if self.waiting_times[i] else 0
            d_serv = (sum([x**2 for x in self.service_times[i]]) / len(self.service_times[i]) - t_serv**2) if self.service_times[i] else 0

            print(f"И{i:<9} | {gen:<14} | {ref:<8} | {p_ref:<8.4f} | {t_total:<8.2f} | {t_wait:<8.2f} | {t_serv:<8.2f} | {d_wait:<8.2f} | {d_serv:<8.2f}")

        print("\nТаблица 2. Характеристики приборов ВС")
        print(f"{'Прибор':<10} | {'Коэффициент использования':<25}")
        print("-" * 40)
        
        for i in range(1, self.num_devices + 1):
            k_use = self.device_busy_time[i] / self.total_model_time if self.total_model_time > 0 else 0
            print(f"П{i:<9} | {k_use:<25.4f}")

def run_auto_mode(num_sources=3, buffer_size=4, num_devices=2, total_bids=1000):
    print("Запуск автоматического режима...")
    
    sources = [Source(i+1, 1.0, 5.0) for i in range(num_sources)] 
    buffer = Buffer(buffer_size)
    devices = [Device(i+1, 4.0) for i in range(num_devices)]     
    dispatcher = DispatcherSelect(buffer, devices)
    
    stats = Statistics(num_sources, num_devices)
    
    event_queue = []
    bid_counter = 1
    total_generated = 0
    current_time = 0
    
    for src in sources:
        heapq.heappush(event_queue, (src.get_next_time(0), "NEW_BID", src))

    while event_queue and total_generated < total_bids:
        current_time, event_type, data = heapq.heappop(event_queue)
        
        if event_type == "NEW_BID":
            src = data
            bid = Bid(bid_counter, src.id, current_time)
            bid_counter += 1
            total_generated += 1
            stats.record_generated(src.id)
            
            if buffer.put_bid(bid):
                trigger_service(current_time, buffer, dispatcher, event_queue, stats)
            else:
                stats.record_refused(src.id)

            heapq.heappush(event_queue, (src.get_next_time(current_time), "NEW_BID", src))

        elif event_type == "END_SERVICE":
            dev, start_time = data 
            busy_duration = current_time - start_time
            stats.record_device_busy(dev.id, busy_duration)
            
            finished_bid = dev.current_bid
            finished_bid.end_service_time = current_time
            stats.record_served(finished_bid)
            
            dev.release()
            trigger_service(current_time, buffer, dispatcher, event_queue, stats)

    stats.total_model_time = current_time
    stats.print_summary()

if __name__ == "__main__":
    run_auto_mode(num_sources=3, buffer_size=20, num_devices=4, total_bids=1000)
