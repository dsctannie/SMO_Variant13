import random
import heapq


class Bid:
    def __init__(self, bid_id: int, source_id: int, arrival_time: float):
        self.__id = bid_id
        self.__source_id = source_id
        self.__arrival_time = arrival_time
        self.start_service_time = None
        self.end_service_time = None

    @property
    def id(self) -> int:
        return self.__id

    @property
    def source_id(self) -> int:
        return self.__source_id

    @property
    def arrival_time(self) -> float:
        return self.__arrival_time


class Source:
    def __init__(self, source_id: int, a: float, b: float):
        self.__id = source_id
        self.__a = a
        self.__b = b

    @property
    def id(self) -> int:
        return self.__id

    def get_next_time(self, current_time: float) -> float:
        # ИЗ2: равномерный закон распределения интервалов поступления
        return current_time + random.uniform(self.__a, self.__b)


class Buffer:
    def __init__(self, capacity: int):
        self.__capacity = capacity
        self.__slots = [None] * capacity

    def is_empty(self) -> bool:
        return all(slot is None for slot in self.__slots)

    def put_bid(self, bid: Bid) -> int:
        # Д1033: постановка на первое свободное место от начала без сдвига остальных
        for i in range(self.__capacity):
            if self.__slots[i] is None:
                self.__slots[i] = bid
                return i
        return -1

    def select_bid(self) -> Bid | None:
        # Д2Б4: приоритет по меньшему номеру источника; при равенстве — последняя поступившая
        best_idx = -1
        best_bid = None
        for i in range(self.__capacity):
            bid = self.__slots[i]
            if bid is not None:
                if best_bid is None:
                    best_bid = bid
                    best_idx = i
                else:
                    if bid.source_id < best_bid.source_id:
                        best_bid = bid
                        best_idx = i
                    elif bid.source_id == best_bid.source_id:
                        if (bid.arrival_time, bid.id) > (best_bid.arrival_time, best_bid.id):
                            best_bid = bid
                            best_idx = i
        if best_idx != -1:
            self.__slots[best_idx] = None
            return best_bid
        return None


class Device:
    def __init__(self, device_id: int, mean_time: float):
        self.__id = device_id
        self.__mean_time = mean_time
        self.__busy = False
        self.__current_bid = None

    @property
    def id(self) -> int:
        return self.__id

    def is_free(self) -> bool:
        return not self.__busy

    def serve(self, bid: Bid, current_time: float) -> float:
        # ПЗ1: экспоненциальное время обслуживания
        self.__busy = True
        self.__current_bid = bid
        bid.start_service_time = current_time
        service_time = random.expovariate(1.0 / self.__mean_time)
        return current_time + service_time

    def release(self, current_time: float) -> Bid | None:
        finished_bid = self.__current_bid
        if finished_bid:
            finished_bid.end_service_time = current_time
        self.__busy = False
        self.__current_bid = None
        return finished_bid


class DispatcherPut:
    """Диспетчер постановки: работает только с буфером (Д1033, Д10О5)."""
    def __init__(self, buffer: Buffer):
        self.__buffer = buffer

    def place_bid(self, bid: Bid) -> int:
        return self.__buffer.put_bid(bid)


class DispatcherSelect:
    """Диспетчер выбора: выбирает заявку из буфера (Д2Б4) и свободный прибор (Д2П1)."""
    def __init__(self, buffer: Buffer, devices: list[Device]):
        self.__buffer = buffer
        self.__devices = devices

    def select_device(self) -> Device | None:
        # Д2П1: последовательный перебор начиная с самого приоритетного (Д1, Д2...)
        for dev in self.__devices:
            if dev.is_free():
                return dev
        return None

    def dispatch(self, current_time: float) -> tuple[Bid, Device, float] | None:
        if self.__buffer.is_empty():
            return None
        free_dev = self.select_device()
        if free_dev is None:
            return None
        bid = self.__buffer.select_bid()
        end_time = free_dev.serve(bid, current_time)
        return bid, free_dev, end_time


class Statistics:
    def __init__(self, num_sources: int, num_devices: int):
        self.num_sources = num_sources
        self.num_devices = num_devices

        self.generated = {i + 1: 0 for i in range(num_sources)}
        self.served = {i + 1: 0 for i in range(num_sources)}
        self.refused = {i + 1: 0 for i in range(num_sources)}

        self.waiting_times = {i + 1: [] for i in range(num_sources)}
        self.service_times = {i + 1: [] for i in range(num_sources)}
        self.total_times = {i + 1: [] for i in range(num_sources)}

        self.device_busy_time = {i + 1: 0.0 for i in range(num_devices)}
        self.total_model_time = 0.0

    def record_served(self, bid: Bid):
        self.served[bid.source_id] += 1
        wait_t = bid.start_service_time - bid.arrival_time
        serv_t = bid.end_service_time - bid.start_service_time
        tot_t = bid.end_service_time - bid.arrival_time

        self.waiting_times[bid.source_id].append(wait_t)
        self.service_times[bid.source_id].append(serv_t)
        self.total_times[bid.source_id].append(tot_t)

    def print_summary(self):
        print("\n" + "=" * 120)
        print("СВОДНАЯ ТАБЛИЦА РЕЗУЛЬТАТОВ (ОР1) — СЛУЖБА ДОСТАВКИ ЕДЫ (ВАРИАНТ 13)")
        print("=" * 120)

        print("\nТаблица 1. Характеристики источников (клиентов)")
        print(
            f"{'Источник':<10} | {'Сгенер.':<8} | {'Обраб.':<8} | {'Отказов':<8} | "
            f"{'P_отк':<8} | {'T_преб':<8} | {'T_ож':<8} | {'T_обсл':<8} | {'D_ож':<8} | {'D_обсл':<8}"
        )
        print("-" * 120)

        for i in range(1, self.num_sources + 1):
            gen = self.generated[i]
            srv = self.served[i]
            ref = self.refused[i]
            p_ref = ref / gen if gen > 0 else 0.0

            n = len(self.waiting_times[i])
            t_wait = sum(self.waiting_times[i]) / n if n > 0 else 0.0
            t_serv = sum(self.service_times[i]) / n if n > 0 else 0.0
            t_tot = sum(self.total_times[i]) / n if n > 0 else 0.0

            d_wait = max(0.0, (sum(x ** 2 for x in self.waiting_times[i]) / n - t_wait ** 2)) if n > 0 else 0.0
            d_serv = max(0.0, (sum(x ** 2 for x in self.service_times[i]) / n - t_serv ** 2)) if n > 0 else 0.0

            print(
                f"И{i:<9} | {gen:<8} | {srv:<8} | {ref:<8} | "
                f"{p_ref:<8.4f} | {t_tot:<8.2f} | {t_wait:<8.2f} | {t_serv:<8.2f} | {d_wait:<8.2f} | {d_serv:<8.2f}"
            )

        print("\nТаблица 2. Характеристики приборов (диспетчеров)")
        print(f"{'Прибор':<10} | {'Коэффициент использования':<25}")
        print("-" * 40)
        for i in range(1, self.num_devices + 1):
            k_use = self.device_busy_time[i] / self.total_model_time if self.total_model_time > 0 else 0.0
            print(f"Д{i:<9} | {k_use:<25.4f}")


def run_auto_mode(num_sources=3, buffer_size=4, num_devices=2, total_bids=1000):
    print("Запуск автоматического режима (ОР1)...")

    sources = [Source(i + 1, 1.0, 5.0) for i in range(num_sources)]
    buffer = Buffer(buffer_size)
    devices = [Device(i + 1, 4.0) for i in range(num_devices)]

    disp_put = DispatcherPut(buffer)
    disp_select = DispatcherSelect(buffer, devices)
    stats = Statistics(num_sources, num_devices)

    event_queue = []
    seq = 0
    bid_counter = 1
    total_gen = 0
    current_time = 0.0

    for src in sources:
        seq += 1
        heapq.heappush(event_queue, (src.get_next_time(0.0), seq, "NEW_BID", src))

     while event_queue:
        current_time, _, event_type, data = heapq.heappop(event_queue)

        if event_type == "NEW_BID":
            if total_gen >= total_bids:
                continue

            src = data
            bid = Bid(bid_counter, src.id, current_time)
            bid_counter += 1
            total_gen += 1
            stats.generated[src.id] += 1

            if total_gen < total_bids:
                seq += 1
                heapq.heappush(event_queue, (src.get_next_time(current_time), seq, "NEW_BID", src))

            # 1. Диспетчер постановки ставит заявку в буфер (Д1033) или отказывает (Д10О5)
            if disp_put.place_bid(bid) != -1:
                # 2. Триггер для диспетчера выбора (Д2Б4 + Д2П1)
                dispatched = disp_select.dispatch(current_time)
                if dispatched:
                    _, dev, end_time = dispatched
                    seq += 1
                    heapq.heappush(event_queue, (end_time, seq, "END_SERVICE", (dev, current_time)))
            else:
                stats.refused[src.id] += 1

        elif event_type == "END_SERVICE":
            dev, start_time = data
            stats.device_busy_time[dev.id] += (current_time - start_time)

            finished_bid = dev.release(current_time)
            stats.record_served(finished_bid)

            # Триггер для диспетчера выбора после освобождения прибора
            dispatched = disp_select.dispatch(current_time)
            if dispatched:
                _, assigned_dev, end_time = dispatched
                seq += 1
                heapq.heappush(event_queue, (end_time, seq, "END_SERVICE", (assigned_dev, current_time)))

    stats.total_model_time = current_time
    stats.print_summary()

    total_refused = sum(stats.refused.values())
    p_avg = total_refused / total_gen if total_gen > 0 else 0.0
    t_alpha = 1.643
    delta = 0.1

    print("\nПроверка достоверности (расчёт необходимого числа реализаций N):")
    if p_avg > 0:
        n_needed = (t_alpha ** 2 * (1 - p_avg)) / (p_avg * delta ** 2)
        print(f"  • Средняя вероятность отказа (p): {p_avg:.4f}")
        print(f"  • Необходимое количество заявок (N) для точности 10%: {int(n_needed)}")
        print(f"  • Фактически прогнано заявок: {total_gen}")
    else:
        print("  • Отказов не зафиксировано (p = 0).")

if __name__ == "__main__":
    run_auto_mode(num_sources=10, buffer_size=10, num_devices=7, total_bids=7000)
    
