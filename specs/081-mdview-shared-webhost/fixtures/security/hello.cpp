// Fixture for checklist row C8 (cross-plugin engine warmth): this file is
// opened with F3 so the CODE viewer starts the shared browser tree; the
// Markdown view that follows must then attach warm, because either plugin's
// keeper keeps the tree alive for both (architecture/11 §2.4).

#include <cstdio>
#include <string>

namespace tandem
{
    struct Greeting
    {
        std::string text = "Tandem Commander";
        int count = 3;
    };

    void say(const Greeting& g)
    {
        for (int i = 0; i < g.count; ++i)
            std::printf("%s %d\n", g.text.c_str(), i);
    }
} // namespace tandem

int main()
{
    tandem::Greeting g;
    tandem::say(g);
    return 0;
}
