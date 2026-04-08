export function DashboardMockup() {
  const students = [
    { name: "Emma S.", books: 5, vocab: "120 words", active: "Today" },
    { name: "Liam K.", books: 3, vocab: "85 words", active: "Yesterday" },
    { name: "Sofia R.", books: 4, vocab: "102 words", active: "Today" },
  ];

  return (
    <div className="text-left select-none">
      {/* Header */}
      <div className="flex items-center justify-between mb-3">
        <h3 className="text-sm font-black text-eel">Class 5-A</h3>
        <span className="text-[10px] font-bold text-sky bg-sky/10 px-2 py-0.5 rounded-full">
          12 Students
        </span>
      </div>

      {/* Stats row */}
      <div className="grid grid-cols-3 gap-2 mb-3">
        {[
          { label: "Books Read", value: "47", color: "text-feather" },
          { label: "Avg. Quiz", value: "82%", color: "text-sky" },
          { label: "Streaks", value: "9", color: "text-fox" },
        ].map((stat) => (
          <div
            key={stat.label}
            className="bg-polar rounded-lg p-2 text-center"
          >
            <div className={`text-lg font-black ${stat.color}`}>
              {stat.value}
            </div>
            <div className="text-[9px] font-bold text-hare uppercase tracking-wider">
              {stat.label}
            </div>
          </div>
        ))}
      </div>

      {/* Student table */}
      <table className="w-full text-[11px]">
        <thead>
          <tr className="text-left text-hare uppercase tracking-wider border-b border-swan">
            <th className="pb-1.5 font-bold">Student</th>
            <th className="pb-1.5 font-bold">Books</th>
            <th className="pb-1.5 font-bold">Vocab</th>
            <th className="pb-1.5 font-bold">Active</th>
          </tr>
        </thead>
        <tbody>
          {students.map((s) => (
            <tr key={s.name} className="border-b border-swan/50">
              <td className="py-1.5 font-bold text-eel">{s.name}</td>
              <td className="py-1.5 text-hare">{s.books}</td>
              <td className="py-1.5 text-hare">{s.vocab}</td>
              <td className="py-1.5">
                <span
                  className={`text-[10px] font-bold ${
                    s.active === "Today" ? "text-feather" : "text-hare"
                  }`}
                >
                  {s.active}
                </span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
