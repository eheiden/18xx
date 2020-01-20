# frozen_string_literal: true

require 'set'

require 'engine/city'
require 'engine/edge'
require 'engine/junction'
require 'engine/town'

# TODO: add white border to track

SHARP = 1
GENTLE = 2
STRAIGHT = 3

module View
  class Tile < Snabberb::Component
    needs :tile

    def lawson?
      @lawson ||= @tile.paths.any? do |p|
        [p.a, p.b].any? { |x| x.is_a?(Engine::Junction) }
      end
    end

    # SHARP, GENTLE, or STRAIGHT
    def compute_curvilinear_type(edge_a, edge_b)
      diff = edge_b - edge_a
      diff = (edge_a - edge_b) % 6 if diff > 3
      diff
    end

    # degrees to rotate the svg path for this track path; e.g., a normal gentle
    # is 0,2; for 1,3, rotate = 60
    def compute_track_rotation(edge_a, edge_b)
      if (edge_b - edge_a) > 3
        60 * edge_b
      else
        60 * edge_a
      end
    end

    # "just track" means no towns/cities
    def render_just_track
      if lawson?
        render_lawson_track
      else
        render_curvilinear_track
      end
    end

    def render_curvilinear_track
      @tile.paths.flat_map do |path|
        render_curvilinear_track_segment(path.a.num, path.b.num)
      end
    end

    def render_curvilinear_track_segment(edge_num_a, edge_num_b)
      a, b = [edge_num_a, edge_num_b].sort

      curvilinear_type = compute_curvilinear_type(a, b)
      rotation = compute_track_rotation(a, b)

      transform = "rotate(#{rotation})"

      d =
        case curvilinear_type
        when SHARP
          'm 0 85 L 0 75 A 43.30125 43.30125 0 0 0 -64.951875 37.5 L -73.612125 42.5'
        when GENTLE
          'm 0 85 L 0 75 A 129.90375 129.90375 0 0 0 -64.951875 -37.5 L -73.612125 -42.5'
        when STRAIGHT
          'm 0 87 L 0 -87'
          # h(:path, attrs: { d: 'm -4 86 L -4 -86', stroke: 'white', 'stroke-width' => 2 }),
          # h(:path, attrs: { d: 'm 4 86 L 4 -86', stroke: 'white',
          # 'stroke-width' => 2 }),
        end

      [
        h(:path, attrs: { transform: transform, d: d, stroke: 'black', 'stroke-width' => 8 }),
      ]
    end

    def render_lawson_track
      edge_nums = @tile.paths.flat_map do |p|
        [p.a, p.b].select { |x| x.is_a?(Engine::Edge) }
      end.map(&:num)
      edge_nums.flat_map { |e| render_lawson_track_segment(e) }
    end

    def render_lawson_track_segment(edge_num)
      rotate = 60 * edge_num

      props = {
        attrs: {
          transform: "rotate(#{rotate})",
          d: 'M 0 87 L 0 0',
          stroke: 'black',
          'stroke-width' => 8
        }
      }

      [
        h(:path, props),
      ]
    end

    def render_revenue(revenue)
      [
        h(
          :g,
          { attrs: { 'stroke-width': 1, transform: "translate(-25 40) rotate(-#{60 * @tile.rotation})" } },
          [
            h(:circle, attrs: { r: 14, fill: 'white' }),
            h(:text, attrs: { transform: 'translate(-8 6)' }, props: { innerHTML: revenue }),
          ]
        )
      ]
    end

    # render the small rectangle representing a town stop between curvilinear
    # track connecting A and B
    def render_town_rect(edge_a, edge_b)
      width = 8
      height = 28

      rotation_edge = (edge_b - edge_a) > 3 ? edge_a : edge_b
      rotation_offset = 60 * rotation_edge

      translation, rotation =
        case compute_curvilinear_type(edge_a, edge_b)
        when SHARP
          [30, -30 + rotation_offset]
        when GENTLE
          [5, -60 + rotation_offset]
        when STRAIGHT
          [-(height / 2), 90 + rotation_offset]
        else
          [0, 0]
        end

      [
        h(
          :g,
          { attrs: { transform: "rotate(#{rotation})" } },
          [
            h(:rect, attrs: {
                transform: "translate(#{-(width / 2)} #{translation})",
                height: height,
                width: width,
                fill: 'black'
              }),
          ]
        )
      ]
    end

    def render_track_single_town
      town = @tile.towns.first
      edges = @tile.paths.flat_map do |p|
        [p.a, p.b].select { |x| x.is_a?(Engine::Edge) }
      end

      if edges.count == 2
        edge_nums = edges.map(&:num).sort
        r_track = render_curvilinear_track_segment(*edge_nums)
        r_town = render_town_rect(*edge_nums)
        r_revenue = render_revenue(town.revenue)
        r_track + r_town + r_revenue

      elsif edges.count == 1
      # TODO, e.g., 371
      elsif edges.count > 2
        # TODO, e.g., 141
      end
    end

    # TODO: support for multiple station locations in one city
    def render_track_single_city
      city = @tile.cities.first

      city_slot = h(:g, { attrs: { transform: '' } }, [
        h(:circle, attrs: { r: 25, fill: 'white' })
      ])

      render_lawson_track + [city_slot] + render_revenue(city.revenue)
    end

    def render_track
      case [@tile.cities.count, @tile.towns.count]
      when [0, 0]
        render_just_track
      when [1, 0]
        render_track_single_city
      when [0, 1]
        render_track_single_town
      else
        raise GameError, "Don't how to render track for #{@tile.towns.count}"\
                         " towns and #{@tile.cities.count} cities on the tile."
      end
    end

    def render
      attrs = {
        transform: "rotate(#{60 * @tile.rotation})",
        'stroke-width' => 1,
      }

      h(:g, { attrs: attrs }, render_track)
    end
  end
end