import Darwin
import Foundation
import os

/// BSD-socket bind probe. Used by the port-range walker in
/// `AICourseBuilderMCPServer.start()` to find the first port the kernel
/// will accept before we hand off to Hummingbird's NIO listener.
///
/// **Why a raw probe instead of `NWListener`.** Earlier SlideFlow versions
/// used `NWListener` with `acceptLocalOnly = true`, which has different
/// bind semantics (binds on all interfaces, filters connections) than
/// NIO's specific-address bind. The mismatch produced false negatives:
/// `NWListener` rejected ports that Hummingbird's
/// `bind("127.0.0.1", port)` would happily take. Same kernel code path
/// for probe and real listener removes the mismatch.
///
/// `SO_REUSEADDR` matches NIO's default. Without it, a port left in
/// `TIME_WAIT` by a previous app process would be rejected here even
/// though NIO would take it.
enum PortProbe {
    static func canBind(host: String, port: Int, log: os.Logger) -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            log.debug(
                "probe socket() failed for \(host, privacy: .public):\(port, privacy: .public) errno=\(errno, privacy: .public)"
            )
            return false
        }
        defer { _ = close(fd) }

        var yes: Int32 = 1
        _ = setsockopt(
            fd, SOL_SOCKET, SO_REUSEADDR,
            &yes, socklen_t(MemoryLayout<Int32>.size)
        )

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        addr.sin_addr.s_addr = inet_addr(host)

        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if result != 0 {
            log.debug(
                "probe bind() rejected \(host, privacy: .public):\(port, privacy: .public) errno=\(errno, privacy: .public)"
            )
            return false
        }
        return true
    }
}
