#pragma once

#include <cstdint>
#include <string>
#include <map>
#include <vector>
#include <future>
#include <chrono>
#include <iomanip>
#include "json.hpp"
#include "string_utils.h"
#include "logger.h"
#include "app_metrics.h"
#include "tsconfig.h"
#include "zlib.h"

#define H2O_USE_LIBUV 0
extern "C" {
    #include "h2o.h"
}

using TimePoint = std::chrono::high_resolution_clock::time_point;

struct h2o_custom_timer_t {
    h2o_timer_t timer;
    void *data;

    h2o_custom_timer_t(): data(nullptr) {}

    explicit h2o_custom_timer_t(void *data): data(data) {

    }
};

enum class ROUTE_CODES {
    NOT_FOUND = 1,
    ALREADY_HANDLED = 2,
};

struct http_res {
    uint32_t status_code;
    std::string content_type_header;
    std::string body;
    std::atomic<bool> final;

    std::shared_mutex mres;

    std::atomic<bool> is_alive;
    std::atomic<void*> generator = nullptr;

    // indicates whether follower is proxying this response stream from leader
    bool proxied_stream = false;

    std::mutex mcv;
    std::condition_variable cv;
    bool ready;

    http_res(void* generator): status_code(0), content_type_header("application/json; charset=utf-8"), final(true),
                               is_alive(generator != nullptr), generator(generator), ready(false) {

    }

    ~http_res() {
        //LOG(INFO) << "~http_res " << this;
    }

    void set_content(uint32_t status_code, const std::string& content_type_header, const std::string& body, const bool final) {
        this->status_code = status_code;
        this->content_type_header = content_type_header;
        this->body = body;
        this->final = final;
    }

    void wait() {
        auto lk = std::unique_lock<std::mutex>(mcv);
        cv.wait(lk, [&] { return ready; });
        ready = false;
    }

    void notify() {
        // Ideally we don't need lock over notify but it is needed here because
        // the parent object could be deleted after lock on mutex is released but
        // before notify can be called on condition variable.
        std::lock_guard<std::mutex> lk(mcv);
        ready = true;
        cv.notify_all();
    }

    static const char* get_status_reason(uint32_t status_code) {
        switch(status_code) {
            case 200: return "OK";
            case 201: return "Created";
            case 400: return "Bad Request";
            case 401: return "Unauthorized";
            case 403: return "Forbidden";
            case 404: return "Not Found";
            case 405: return "Not Allowed";
            case 409: return "Conflict";
            case 422: return "Unprocessable Entity";
            case 429: return "Too Many Requests";
            case 500: return "Internal Server Error";
            default: return "";
        }
    }

    void set_200(const std::string & res_body) {
        status_code = 200;
        body = res_body;
    }

    void set_201(const std::string & res_body) {
        status_code = 201;
        body = res_body;
    }

    void set_400(const std::string & message) {
        status_code = 400;
        body = "{\"message\": \"" + message + "\"}";
    }

    void set_401(const std::string & message) {
        status_code = 400;
        body = "{\"message\": \"" + message + "\"}";
    }

    void set_403() {
        status_code = 403;
        body = "{\"message\": \"Forbidden\"}";
    }

    void set_404() {
        status_code = 404;
        body = "{\"message\": \"Not Found\"}";
    }

    void set_405(const std::string & message) {
        status_code = 405;
        body = "{\"message\": \"" + message + "\"}";
    }

    void set_409(const std::string & message) {
        status_code = 409;
        body = "{\"message\": \"" + message + "\"}";
    }

    void set_422(const std::string & message) {
        status_code = 422;
        body = "{\"message\": \"" + message + "\"}";
    }

    void set_500(const std::string & message) {
        status_code = 500;
        body = "{\"message\": \"" + message + "\"}";
    }

    void set_503(const std::string & message) {
        status_code = 503;
        body = "{\"message\": \"" + message + "\"}";
    }

    void set(uint32_t code, const std::string & message) {
        status_code = code;
        body = "{\"message\": \"" + message + "\"}";
    }

    void set_body(uint32_t code, const std::string & message) {
        status_code = code;
        body = message;
    }
};

struct cached_res_t {
    uint32_t status_code;
    std::string content_type_header;
    std::string body;
    TimePoint created_at;
    uint32_t ttl;
    uint64_t hash;

    bool operator == (const cached_res_t& res) const {
        return hash == res.hash;
    }

    bool operator != (const cached_res_t& res) const {
        return hash != res.hash;
    }

    void load(uint32_t status_code, const std::string& content_type_header, const std::string& body,
              const TimePoint created_at, const uint32_t ttl, uint64_t hash) {
        this->status_code = status_code;
        this->content_type_header = content_type_header;
        this->body = body;
        this->created_at = created_at;
        this->ttl = ttl;
        this->hash = hash;
    }
};

struct ip_addr_str_t {
    static const size_t IP_MAX_LEN = 64;
    char ip[IP_MAX_LEN];
};

struct req_state_t {
public:
    virtual ~req_state_t() = default;
};

struct stream_response_state_t {
private:

    h2o_req_t* req = nullptr;

public:

    bool is_req_early_exit = false;

    bool is_res_start = true;
    h2o_send_state_t send_state = H2O_SEND_STATE_IN_PROGRESS;

    std::string res_body;
    h2o_iovec_t res_buff;

    std::string res_content_type;
    int status = 0;
    const char* reason = nullptr;

    h2o_generator_t* generator = nullptr;

    void set_response(uint32_t status_code, const std::string& content_type, std::string& body) {
        std::string().swap(res_body);
        res_body = std::move(body);
        res_buff = h2o_iovec_t{.base = res_body.data(), .len = res_body.size()};

        if(is_res_start) {
            res_content_type = std::move(content_type);
            status = (int)status_code;
            reason = http_res::get_status_reason(status_code);
            is_res_start = false;
        }
    }

    void set_req(h2o_req_t* _req) {
        req = _req;
    }

    h2o_req_t* get_req() {
        return req;
    }
};

struct http_req {
    static constexpr const char* AUTH_HEADER = "x-typosearch-api-key";
    static constexpr const char* USER_HEADER = "x-typosearch-user-id";
    static constexpr const char* AGENT_HEADER = "user-agent";
    static constexpr const char* CONTENT_TYPE_HEADER = "content-type";
    static constexpr const char* OCTET_STREAM_HEADER_VALUE = "application/octet-stream";

    h2o_req_t* _req;
    std::string http_method;
    std::string path_without_query;
    uint64_t route_hash;
    std::map<std::string, std::string> params;
    std::vector<nlohmann::json> embedded_params_vec;
    std::string api_auth_key;

    bool first_chunk_aggregate;
    std::atomic<bool> last_chunk_aggregate;
    size_t chunk_len;

    std::string body;
    size_t body_index;
    std::string metadata;

    req_state_t* data;

    // for deffered processing of async handlers
    h2o_custom_timer_t defer_timer;

    uint64_t start_ts;

    // timestamp from the underlying http library
    uint64_t conn_ts;

    // was the request aborted *without a result* because of wait time exceeding search cutoff threshold?
    bool overloaded = false;

    std::mutex mcv;
    std::condition_variable cv;
    bool ready;

    int64_t log_index;

    std::atomic<bool> is_diposed;
    std::string client_ip = "0.0.0.0";

    z_stream zs;
    bool zstream_initialized = false;

    // stores http lib related datastructures to avoid race conditions between indexing and http write threads
    stream_response_state_t res_state;

    bool is_binary_body = false;

    http_req(): _req(nullptr), route_hash(1),
                first_chunk_aggregate(true), last_chunk_aggregate(false),
                chunk_len(0), body_index(0), data(nullptr), ready(false), log_index(0),
                is_diposed(false) {

        start_ts = std::chrono::duration_cast<std::chrono::microseconds>(
                std::chrono::system_clock::now().time_since_epoch()).count();

        conn_ts = start_ts;

    }

    http_req(h2o_req_t* _req, const std::string & http_method, const std::string & path_without_query, uint64_t route_hash,
            const std::map<std::string, std::string>& params, std::vector<nlohmann::json>& embedded_params_vec,
            const std::string& api_auth_key, const std::string& body, const std::string& client_ip, bool is_binary_body):
            _req(_req), http_method(http_method), path_without_query(path_without_query), route_hash(route_hash),
            params(params), embedded_params_vec(embedded_params_vec), api_auth_key(api_auth_key),
            first_chunk_aggregate(true), last_chunk_aggregate(false),
            chunk_len(0), body(body), body_index(0), data(nullptr), ready(false),
            log_index(0), is_diposed(false), client_ip(client_ip), is_binary_body(is_binary_body) {

        if(_req != nullptr) {
            const auto& tv = _req->processed_at.at;
            conn_ts = (tv.tv_sec * 1000 * 1000) + tv.tv_usec;
        } else {
            conn_ts = std::chrono::duration_cast<std::chrono::microseconds>(
                        std::chrono::system_clock::now().time_since_epoch()).count();
        }

        start_ts = std::chrono::duration_cast<std::chrono::microseconds>(
                std::chrono::system_clock::now().time_since_epoch()).count();
    }

    ~http_req() {

        //LOG(INFO) << "~http_req " << this;
        if(_req != nullptr) {
            Config& config = Config::get_instance();

            uint64_t now = std::chrono::duration_cast<std::chrono::microseconds>(
                    std::chrono::system_clock::now().time_since_epoch()).count();
            uint64_t ms_since_start = (now - start_ts) / 1000;

            const std::string metric_identifier = http_method + " " + path_without_query;
            AppMetrics::get_instance().increment_duration(metric_identifier, ms_since_start);
            AppMetrics::get_instance().increment_write_metrics(route_hash, ms_since_start);

            bool log_slow_searches = config.get_log_slow_searches_time_ms() >= 0 &&
                                     int(ms_since_start) >= config.get_log_slow_searches_time_ms() &&
                                     (path_without_query == "/multi_search" ||
                                      StringUtils::ends_with(path_without_query, "/documents/search"));

            bool log_slow_requests = config.get_log_slow_requests_time_ms() >= 0 &&
                                     int(ms_since_start) >= config.get_log_slow_requests_time_ms();

            if(overloaded) {
                AppMetrics::get_instance().increment_count(AppMetrics::OVERLOADED_LABEL, 1);
            } else if(log_slow_searches || log_slow_requests) {
                // log slow request if logging is enabled
                bool is_multi_search_query = (path_without_query == "/multi_search");
                std::string query_string = "?";

                if(is_multi_search_query) {
                    StringUtils::erase_char(body, '\n');
                }

                for(const auto& kv: params) {
                    if(kv.first != AUTH_HEADER) {
                        query_string += kv.first + "=" + kv.second + "&";
                    }
                }

                std::string full_url_path = metric_identifier + query_string;

                // NOTE: we log the `body` ONLY for multi-search query
                LOG(INFO) << "event=slow_request, time=" << ms_since_start << " ms"
                          << ", client_ip=" << client_ip << ", endpoint=" << full_url_path
                          << ", body=" << (is_multi_search_query ? body : "");
            }
        }

        delete data;
        data = nullptr;

        if(zstream_initialized) {
            zstream_initialized = false;
            inflateEnd(&zs);
        }
    }

    void wait() {
        auto lk = std::unique_lock<std::mutex>(mcv);
        cv.wait(lk, [&] { return ready; });
        ready = false;
    }

    void notify() {
        // Ideally we don't need lock over notify but it is needed here because
        // the parent object could be deleted after lock on mutex is released but
        // before notify can be called on condition variable.
        std::lock_guard<std::mutex> lk(mcv);
        ready = true;
        cv.notify_all();
    }

    // NOTE: we don't ser/de all fields, only ones needed for write forwarding
    // Take care to check for existence of key to ensure backward compatibility during upgrade

    void load_from_json(const std::string& json_str) {
        nlohmann::json j = nlohmann::json::parse(json_str);
        route_hash = j["route_hash"];

        std::string chunk_body;
        is_binary_body = j.count("is_binary_body") != 0 ? j["is_binary_body"].get<bool>() : false;
        if (is_binary_body) {
            chunk_body = StringUtils::base64_decode(j["body"]);
        } else {
            chunk_body = j["body"];
        }

        if(start_ts == 0) {
            // Serialized request from an older version (v0.21 and below) which serializes import data differently.
            body = chunk_body;
        } else {
            body += chunk_body;
        }

        for (nlohmann::json::iterator it = j["params"].begin(); it != j["params"].end(); ++it) {
            params.emplace(it.key(), it.value());
        }

        metadata = j.count("metadata") != 0 ? j["metadata"] : "";
        first_chunk_aggregate = j.count("first_chunk_aggregate") != 0 ? j["first_chunk_aggregate"].get<bool>() : true;
        last_chunk_aggregate = j.count("last_chunk_aggregate") != 0 ? j["last_chunk_aggregate"].get<bool>() : false;
        start_ts = j.count("start_ts") != 0 ? j["start_ts"].get<uint64_t>() : 0;
        log_index = j.count("log_index") != 0 ? j["log_index"].get<int64_t>() : 0;
    }

    std::string to_json() const {
        nlohmann::json j;
        j["route_hash"] = route_hash;
        j["params"] = params;
        j["first_chunk_aggregate"] = first_chunk_aggregate;
        j["last_chunk_aggregate"] = last_chunk_aggregate.load();
        j["body"] = body;
        j["metadata"] = metadata;
        j["start_ts"] = start_ts;
        j["log_index"] = log_index;
        j["is_binary_body"] = is_binary_body;
        if (is_binary_body) {
            j["body"] = StringUtils::base64_encode(body);
        }
        const std::string j_dump = j.dump(-1, ' ', false, nlohmann::detail::error_handler_t::ignore);
        return j_dump;
    }

    static ip_addr_str_t get_ip_addr(h2o_req_t* h2o_req) {
        ip_addr_str_t ip_addr;
        sockaddr sa;
        if(0 != h2o_req->conn->callbacks->get_peername(h2o_req->conn, &sa)) {
            StringUtils::get_ip_str(&sa, ip_addr.ip, ip_addr.IP_MAX_LEN);
        } else {
            strcpy(ip_addr.ip, "0.0.0.0");
        }

        return ip_addr;
    }

    bool do_resource_check();
};

struct route_path {
    std::string http_method;
    std::vector<std::string> path_parts;
    bool (*handler)(const std::shared_ptr<http_req>&, const std::shared_ptr<http_res>&) = nullptr;
    bool async_req;
    bool async_res;
    std::string action;

    route_path(const std::string &httpMethod, const std::vector<std::string> &pathParts,
               bool (*handler)(const std::shared_ptr<http_req>&, const std::shared_ptr<http_res>&), bool async_req, bool async_res) :
            http_method(httpMethod), path_parts(pathParts), handler(handler),
            async_req(async_req), async_res(async_res) {
        action = _get_action();
        if(async_req) {
            // once a request is async, response also needs to be async
            this->async_res = true;
        }
    }

    inline bool operator< (const route_path& rhs) const {
        return true;
    }

    uint64_t route_hash() {
        std::string path = StringUtils::join(path_parts, "/");
        std::string method_path = http_method + path;
        uint64_t hash = StringUtils::hash_wy(method_path.c_str(), method_path.size());
        return (hash > 100) ? hash : (hash + 100);  // [0-99] reserved for special codes
    }

    std::string _get_action();
};

struct h2o_custom_res_message_t {
    h2o_multithread_message_t super;
    std::map<std::string, bool (*)(void*)> *message_handlers;
    std::string type;
    void* data;
};

struct http_message_dispatcher {
    h2o_multithread_queue_t* message_queue;
    h2o_multithread_receiver_t* message_receiver;
    std::map<std::string, bool (*)(void*)> message_handlers;

    void init(h2o_loop_t *loop) {
        message_queue = h2o_multithread_create_queue(loop);
        message_receiver = new h2o_multithread_receiver_t();
        h2o_multithread_register_receiver(message_queue, message_receiver, on_message);
    }

    ~http_message_dispatcher() {
        // drain existing messages
        on_message(message_receiver, &message_receiver->_messages);

        h2o_multithread_unregister_receiver(message_queue, message_receiver);
        h2o_multithread_destroy_queue(message_queue);

        delete message_receiver;
    }

    static void on_message(h2o_multithread_receiver_t *receiver, h2o_linklist_t *messages) {
        while (!h2o_linklist_is_empty(messages)) {
            h2o_multithread_message_t *message = H2O_STRUCT_FROM_MEMBER(h2o_multithread_message_t, link, messages->next);
            h2o_custom_res_message_t *custom_message = reinterpret_cast<h2o_custom_res_message_t*>(message);

            const std::map<std::string, bool (*)(void*)>::const_iterator handler_itr =
                    custom_message->message_handlers->find(custom_message->type);

            if(handler_itr != custom_message->message_handlers->end()) {
                auto handler = handler_itr->second;
                (handler)(custom_message->data);
            }

            h2o_linklist_unlink(&message->link);
            delete custom_message;
        }
    }

    void send_message(const std::string & type, void* data) {
        h2o_custom_res_message_t* message = new h2o_custom_res_message_t{{{nullptr, nullptr}}, &message_handlers, type, data};
        h2o_multithread_send_message(message_receiver, &message->super);
    }

    void on(const std::string & message, bool (*handler)(void*)) {
        message_handlers.emplace(message, handler);
    }
};

struct async_stream_response_t {
    std::vector<std::string> response_chunks;
    std::mutex mutex;
    std::condition_variable cv;
    bool ready = false;
};

